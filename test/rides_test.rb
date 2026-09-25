require_relative 'test_helper'
require_relative '../app'

class RidesTest < Minitest::Test
  include Rack::Test::Methods

  def app
    TramsApp
  end

  def setup
    super
    @model_a = Model.create!(name: 'M29')
    @model_b = Model.create!(name: 'M32')
    @tram_a = Tram.create!(number: '101', model: @model_a)
    @tram_b = Tram.create!(number: '201', model: @model_b)
    @user = User.create!(name: 'Anna', email: 'anna@example.com', password: 'secret123', password_confirmation: 'secret123')
    @other_user = User.create!(name: 'Bo', email: 'bo@example.com', password: 'secret123', password_confirmation: 'secret123')
  end

  def login(user = @user)
    post '/login', email: user.email, password: 'secret123'
  end

  def fmt(date)
    date.strftime('%-d %b')
  end

  def test_redirects_to_login_when_not_logged_in
    get '/rides'

    assert_equal 302, last_response.status
    assert_includes last_response.location, '/login'
  end

  def test_renders_empty_state_for_a_user_with_no_rides
    login
    get '/rides'

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Du har inte loggat några resor än'
  end

  def test_lists_only_the_current_users_rides
    login
    Ride.create!(user: @user, tram: @tram_a, line: 3, ridden_on: Date.today)
    Ride.create!(user: @other_user, tram: @tram_b, line: 4, ridden_on: Date.today - 60)

    get '/rides'
    body = last_response.body

    assert_includes body, '101'
    assert_includes body, 'M29'
    assert_includes body, fmt(Date.today)
    refute_includes body, fmt(Date.today - 60)
  end

  def test_filters_by_line
    login
    Ride.create!(user: @user, tram: @tram_a, line: 3, ridden_on: Date.today)
    Ride.create!(user: @user, tram: @tram_a, line: 5, ridden_on: Date.today - 10)

    get '/rides', 'lines[]' => ['3']
    body = last_response.body

    assert_includes body, fmt(Date.today)
    refute_includes body, fmt(Date.today - 10)
  end

  def test_filters_by_model
    login
    Ride.create!(user: @user, tram: @tram_a, line: 3, ridden_on: Date.today)
    Ride.create!(user: @user, tram: @tram_b, line: 3, ridden_on: Date.today - 10)

    get '/rides', 'model_ids[]' => [@model_a.id.to_s]
    body = last_response.body

    assert_includes body, fmt(Date.today)
    refute_includes body, fmt(Date.today - 10)
  end

  def test_filters_by_date_range
    login
    Ride.create!(user: @user, tram: @tram_a, line: 3, ridden_on: Date.today)
    Ride.create!(user: @user, tram: @tram_a, line: 3, ridden_on: Date.today - 60)

    get '/rides', from: (Date.today - 5).to_s, to: Date.today.to_s
    body = last_response.body

    assert_includes body, fmt(Date.today)
    refute_includes body, fmt(Date.today - 60)
  end

  def test_renders_filtered_empty_state_when_filters_match_nothing
    login
    Ride.create!(user: @user, tram: @tram_a, line: 3, ridden_on: Date.today)

    get '/rides', 'lines[]' => ['7']
    body = last_response.body

    assert_includes body, 'Inga resor matchar filtren'
    refute_includes body, 'Du har inte loggat några resor än'
  end

  def test_paginates_when_there_are_many_rides
    login
    30.times do |i|
      Ride.create!(user: @user, tram: @tram_a, line: (i % 12) + 1, ridden_on: Date.today - i)
    end

    get '/rides'
    body = last_response.body

    assert_equal 200, last_response.status
    assert_includes body, fmt(Date.today)
    refute_includes body, fmt(Date.today - 29)

    total_pages = body[/Sida \d+ av (\d+)/, 1].to_i
    assert total_pages > 1, 'expected more than one page of results'

    get '/rides', page: total_pages
    assert_includes last_response.body, fmt(Date.today - 29)
  end

  def test_deleting_a_ride_redirects_to_the_given_redirect_to
    login
    ride = Ride.create!(user: @user, tram: @tram_a, line: 3, ridden_on: Date.today)

    post "/rides/#{ride.id}", _method: 'DELETE', redirect_to: '/rides?lines%5B%5D=3'

    assert_equal 302, last_response.status
    assert_equal '/rides?lines%5B%5D=3', last_response.location
    assert_nil Ride.find_by(id: ride.id)
  end

  def test_deleting_a_ride_falls_back_to_the_tram_page_without_redirect_to
    login
    ride = Ride.create!(user: @user, tram: @tram_a, line: 3, ridden_on: Date.today)

    post "/rides/#{ride.id}", _method: 'DELETE'

    assert_equal 302, last_response.status
    assert_includes last_response.location, "/trams/#{@tram_a.id}"
  end

  def test_deleting_a_ride_ignores_an_off_site_redirect_to
    login
    ride = Ride.create!(user: @user, tram: @tram_a, line: 3, ridden_on: Date.today)

    post "/rides/#{ride.id}", _method: 'DELETE', redirect_to: 'https://evil.example.com'

    assert_equal 302, last_response.status
    assert_includes last_response.location, "/trams/#{@tram_a.id}"
  end

  def test_cannot_delete_another_users_ride
    login
    ride = Ride.create!(user: @other_user, tram: @tram_a, line: 3, ridden_on: Date.today)

    post "/rides/#{ride.id}", _method: 'DELETE'

    assert_equal 401, last_response.status
    assert Ride.exists?(ride.id)
  end
end
