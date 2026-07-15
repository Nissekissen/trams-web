require_relative 'test_helper'
require_relative '../api'

class ApiTest < Minitest::Test
  include Rack::Test::Methods

  def app
    TramsApi
  end

  def setup
    super
    @model = Model.create!(name: 'M32')
    @tram = Tram.create!(number: '101', model: @model)
    @user = User.create!(name: 'Anna', email: 'anna@example.com', password: 'secret123', password_confirmation: 'secret123')
  end

  def post_json(path, body, headers = {})
    post path, body.to_json, headers.merge('CONTENT_TYPE' => 'application/json')
  end

  def auth_header(token)
    { 'HTTP_AUTHORIZATION' => "Bearer #{token}" }
  end

  # --- Bearer token filter -------------------------------------------------

  def test_protected_route_without_a_token_is_unauthorized
    get '/me'
    assert_equal 401, last_response.status
  end

  def test_protected_route_with_an_invalid_token_is_unauthorized
    get '/me', {}, auth_header('not-a-real-token')
    assert_equal 401, last_response.status
  end

  def test_protected_route_with_a_valid_token_succeeds
    token = @user.generate_token
    get '/me', {}, auth_header(token)
    assert_equal 200, last_response.status
  end

  def test_auth_routes_do_not_require_a_token
    post_json '/auth/login', { email: 'anna@example.com', password: 'secret123' }
    assert_equal 200, last_response.status
  end

  # --- POST /auth/login -----------------------------------------------------

  def test_login_with_correct_credentials_returns_a_token_and_user
    post_json '/auth/login', { email: 'anna@example.com', password: 'secret123' }

    assert_equal 200, last_response.status
    body = JSON.parse(last_response.body)
    assert body['token']
    assert_equal 'anna@example.com', body['user']['email']
  end

  def test_login_with_wrong_password_is_unauthorized
    post_json '/auth/login', { email: 'anna@example.com', password: 'wrong' }
    assert_equal 401, last_response.status
  end

  def test_login_with_unknown_email_is_unauthorized
    post_json '/auth/login', { email: 'nobody@example.com', password: 'secret123' }
    assert_equal 401, last_response.status
  end

  def test_login_for_a_user_without_a_password_set_is_unauthorized
    @user.update_columns(password_set: false)
    post_json '/auth/login', { email: 'anna@example.com', password: 'secret123' }
    assert_equal 401, last_response.status
  end

  def test_login_with_a_missing_email_is_a_bad_request
    post_json '/auth/login', { password: 'secret123' }
    assert_equal 400, last_response.status
  end

  def test_login_with_a_missing_password_is_a_bad_request
    post_json '/auth/login', { email: 'anna@example.com' }
    assert_equal 400, last_response.status
  end

  # --- POST /auth/google ----------------------------------------------------

  def stub_google_payload(payload)
    Google::Auth::IDTokens.stub(:verify_oidc, ->(_token, aud:) { payload }) { yield }
  end

  def test_google_login_creates_a_new_user_when_no_match_exists
    payload = { 'sub' => 'google-uid-1', 'email' => 'new@example.com', 'name' => 'New Person', 'email_verified' => true }

    stub_google_payload(payload) do
      post_json '/auth/google', { id_token: 'fake' }
    end

    assert_equal 200, last_response.status
    user = User.find_by(email: 'new@example.com')
    refute_nil user
    assert_equal 'google-uid-1', user.google_uid
    refute user.password_set
  end

  def test_google_login_finds_an_existing_user_by_google_uid
    @user.update!(google_uid: 'google-uid-2')
    payload = { 'sub' => 'google-uid-2', 'email' => 'anna@example.com', 'name' => 'Anna', 'email_verified' => true }

    stub_google_payload(payload) do
      post_json '/auth/google', { id_token: 'fake' }
    end

    assert_equal 200, last_response.status
    body = JSON.parse(last_response.body)
    assert_equal @user.id, body['user']['id']
  end

  def test_google_login_links_an_existing_password_account_by_email
    payload = { 'sub' => 'google-uid-3', 'email' => 'anna@example.com', 'name' => 'Anna', 'email_verified' => true }

    stub_google_payload(payload) do
      post_json '/auth/google', { id_token: 'fake' }
    end

    assert_equal 200, last_response.status
    assert_equal 'google-uid-3', @user.reload.google_uid
    assert @user.password_set # existing password login must still work afterward
  end

  def test_google_login_rejects_an_unverified_email
    payload = { 'sub' => 'google-uid-4', 'email' => 'new@example.com', 'name' => 'New', 'email_verified' => false }

    stub_google_payload(payload) do
      post_json '/auth/google', { id_token: 'fake' }
    end

    assert_equal 401, last_response.status
    assert_nil User.find_by(email: 'new@example.com')
  end

  def test_google_login_rejects_an_invalid_token
    Google::Auth::IDTokens.stub(:verify_oidc, ->(_token, aud:) { raise Google::Auth::IDTokens::VerificationError, 'bad token' }) do
      post_json '/auth/google', { id_token: 'garbage' }
    end

    assert_equal 401, last_response.status
  end

  # --- POST /link_google ------------------------------------------------------

  def test_post_link_google_links_the_current_user_and_returns_a_token_and_user
    payload = { 'sub' => 'google-uid-5', 'email' => 'new@example.com', 'name' => 'New', 'email_verified' => true }
    token = @user.generate_token

    stub_google_payload(payload) do
      post_json '/auth/link_google', { id_token: 'fake' }, auth_header(token)
    end

    assert_equal 200, last_response.status
    body = JSON.parse(last_response.body)
    assert body['token']
    assert_equal @user.id, body['user']['id']
    assert_equal 'google-uid-5', @user.reload.google_uid
  end

  def test_post_link_google_requires_authentication
    post_json '/auth/link_google', { id_token: 'fake' }

    assert_equal 401, last_response.status
  end

  def test_post_link_google_with_a_missing_id_token_is_a_bad_request
    token = @user.generate_token
    post_json '/auth/link_google', {}, auth_header(token)

    assert_equal 400, last_response.status
  end

  def test_post_link_google_rejects_an_invalid_token
    token = @user.generate_token

    Google::Auth::IDTokens.stub(:verify_oidc, ->(_token, aud:) { raise Google::Auth::IDTokens::VerificationError, 'bad token' }) do
      post_json '/auth/link_google', { id_token: 'garbage' }, auth_header(token)
    end

    assert_equal 401, last_response.status
  end

  def test_post_link_google_rejects_an_unverified_email
    payload = { 'sub' => 'google-uid-6', 'email' => 'new2@example.com', 'name' => 'New', 'email_verified' => false }
    token = @user.generate_token

    stub_google_payload(payload) do
      post_json '/auth/link_google', { id_token: 'fake' }, auth_header(token)
    end

    assert_equal 401, last_response.status
    refute @user.reload.google_uid
  end

  def test_post_link_google_rejects_a_user_who_already_has_a_linked_google_account
    @user.update!(google_uid: 'already-linked-uid')
    payload = { 'sub' => 'google-uid-7', 'email' => 'new3@example.com', 'name' => 'New', 'email_verified' => true }
    token = @user.generate_token

    stub_google_payload(payload) do
      post_json '/auth/link_google', { id_token: 'fake' }, auth_header(token)
    end

    assert_equal 400, last_response.status
    assert_equal 'already-linked-uid', @user.reload.google_uid
  end

  def test_post_link_google_rejects_a_google_account_already_linked_to_someone_else
    User.create!(name: 'Bob', email: 'bob@example.com', password: 'secret123', password_confirmation: 'secret123', google_uid: 'taken-uid')
    payload = { 'sub' => 'taken-uid', 'email' => 'bob@example.com', 'name' => 'Bob', 'email_verified' => true }
    token = @user.generate_token

    stub_google_payload(payload) do
      post_json '/auth/link_google', { id_token: 'fake' }, auth_header(token)
    end

    assert_equal 400, last_response.status
    refute @user.reload.google_uid
  end



  # --- GET /trams -------------------------------------------------------------

  def test_get_trams_returns_a_flat_list_with_embedded_model
    token = @user.generate_token
    get '/trams', {}, auth_header(token)

    assert_equal 200, last_response.status
    trams = JSON.parse(last_response.body)
    assert_equal 1, trams.length
    assert_equal @model.id, trams.first['model']['id']
  end

  # --- GET /me, /me/stats, /me/rides ------------------------------------------

  def test_get_me_returns_the_current_user
    token = @user.generate_token
    get '/me', {}, auth_header(token)

    body = JSON.parse(last_response.body)
    assert_equal @user.id, body['id']
  end

  def test_get_me_stats_returns_the_stats_block
    token = @user.generate_token
    Ride.create!(user: @user, tram: @tram, line: 1, ridden_on: Date.today)

    get '/me/stats', {}, auth_header(token)

    body = JSON.parse(last_response.body)
    assert_equal 1, body['rideCount']
  end

  def test_get_me_rides_returns_the_users_rides_most_recent_first
    token = @user.generate_token
    older = Ride.create!(user: @user, tram: @tram, line: 1, ridden_on: Date.today - 1)
    newer = Ride.create!(user: @user, tram: @tram, line: 2, ridden_on: Date.today)

    get '/me/rides', {}, auth_header(token)

    ids = JSON.parse(last_response.body).map { |r| r['id'] }
    assert_equal [newer.id, older.id], ids
  end

  def test_get_me_rides_respects_a_valid_limit
    token = @user.generate_token
    3.times { |i| Ride.create!(user: @user, tram: @tram, line: 1, ridden_on: Date.today - i) }

    get '/me/rides', { limit: '2' }, auth_header(token)

    assert_equal 200, last_response.status
    assert_equal 2, JSON.parse(last_response.body).length
  end

  def test_get_me_rides_with_a_non_numeric_limit_is_a_bad_request
    token = @user.generate_token
    get '/me/rides', { limit: 'abc' }, auth_header(token)

    assert_equal 400, last_response.status
  end

  def test_get_me_rides_with_a_negative_limit_is_a_bad_request
    token = @user.generate_token
    get '/me/rides', { limit: '-1' }, auth_header(token)

    assert_equal 400, last_response.status
  end

  # --- POST /rides --------------------------------------------------------

  def test_create_ride_succeeds_with_valid_params
    token = @user.generate_token

    post_json '/rides', { tramId: @tram.id, lineNumber: 3, riddenOn: Date.today.to_s }, auth_header(token)

    assert_equal 200, last_response.status
    body = JSON.parse(last_response.body)
    refute_nil body['ride']['id']
    assert_equal 1, body['user']['stats']['rideCount']
  end

  def test_create_ride_with_an_invalid_line_returns_422
    token = @user.generate_token

    post_json '/rides', { tramId: @tram.id, lineNumber: 99, riddenOn: Date.today.to_s }, auth_header(token)

    assert_equal 422, last_response.status
  end

  def test_create_ride_with_a_nonexistent_tram_does_not_raise
    token = @user.generate_token

    post_json '/rides', { tramId: 999_999, lineNumber: 1, riddenOn: Date.today.to_s }, auth_header(token)

    assert_equal 422, last_response.status
  end

  # --- DELETE /rides/:id ----------------------------------------------------

  def test_delete_ride_removes_the_callers_own_ride
    token = @user.generate_token
    ride = Ride.create!(user: @user, tram: @tram, line: 1, ridden_on: Date.today)

    delete "/rides/#{ride.id}", {}, auth_header(token)

    assert_equal 200, last_response.status
    assert_nil Ride.find_by(id: ride.id)
  end

  def test_delete_ride_for_a_ride_owned_by_someone_else_returns_404
    other_user = User.create!(name: 'Bob', email: 'bob@example.com', password: 'secret123', password_confirmation: 'secret123')
    ride = Ride.create!(user: other_user, tram: @tram, line: 1, ridden_on: Date.today)

    token = @user.generate_token
    delete "/rides/#{ride.id}", {}, auth_header(token)

    assert_equal 404, last_response.status
    refute_nil Ride.find_by(id: ride.id)
  end

  def test_delete_nonexistent_ride_returns_404
    token = @user.generate_token
    delete '/rides/999999', {}, auth_header(token)

    assert_equal 404, last_response.status
  end
end
