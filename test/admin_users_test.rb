require_relative 'test_helper'
require_relative '../app'

class AdminUsersTest < Minitest::Test
  include Rack::Test::Methods

  def app
    TramsApp
  end

  def setup
    super
    @admin = User.create!(name: 'Elin Söderberg', email: 'elin@example.com', password: 'secret123', password_confirmation: 'secret123', is_admin: true)
    @user  = User.create!(name: 'Johan Ahlgren', email: 'johan@example.com', password: 'secret123', password_confirmation: 'secret123')
  end

  def login(user)
    post '/login', email: user.email, password: 'secret123'
  end

  def test_redirects_to_login_when_not_logged_in
    get '/admin/users'

    assert_equal 302, last_response.status
    assert_includes last_response.location, '/login'
  end

  def test_redirects_non_admins_to_home
    login(@user)
    get '/admin/users'

    assert_equal 302, last_response.status
    assert_equal '/', URI(last_response.location).path
  end

  def test_lists_every_user_with_their_stats
    login(@admin)

    model = Model.create!(name: 'M32')
    tram_a = Tram.create!(number: '101', model: model)
    tram_b = Tram.create!(number: '201', model: model)
    Ride.create!(user: @user, tram: tram_a, line: 3, ridden_on: Date.today)
    Ride.create!(user: @user, tram: tram_a, line: 3, ridden_on: Date.today - 1)
    Ride.create!(user: @user, tram: tram_b, line: 5, ridden_on: Date.today - 2)

    get '/admin/users'
    body = last_response.body

    assert_equal 200, last_response.status
    assert_includes body, 'Elin Söderberg'
    assert_includes body, 'elin@example.com'
    assert_includes body, 'Johan Ahlgren'
    assert_includes body, 'johan@example.com'

    # Johan: 3 rides, 2 distinct trams, 2 distinct lines
    assert_includes body, '>3<'
    assert_includes body, '>2<'
    assert_includes body, '2/12'
  end

  def test_marks_admin_accounts_with_a_badge
    login(@admin)
    get '/admin/users'

    assert_includes last_response.body, 'Admin'
  end

  def test_users_with_no_rides_show_zeroed_stats
    login(@admin)
    get '/admin/users'

    assert_includes last_response.body, '0/12'
  end
end
