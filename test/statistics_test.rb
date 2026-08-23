require_relative 'test_helper'
require_relative '../app'

class StatisticsTest < Minitest::Test
  include Rack::Test::Methods

  def app
    TramsApp
  end

  def setup
    super
    @model_a = Model.create!(name: 'M29')
    @model_b = Model.create!(name: 'M32')
    @tram_a1 = Tram.create!(number: '101', model: @model_a)
    @tram_b1 = Tram.create!(number: '201', model: @model_b)
    @tram_b2 = Tram.create!(number: '202', model: @model_b)
    @user = User.create!(name: 'Anna', email: 'anna@example.com', password: 'secret123', password_confirmation: 'secret123')
  end

  def login
    post '/login', email: @user.email, password: 'secret123'
  end

  def test_redirects_to_login_when_not_logged_in
    get '/statistics'

    assert_equal 302, last_response.status
    assert_includes last_response.location, '/login'
  end

  def test_renders_an_empty_state_for_a_user_with_no_rides
    login
    get '/statistics'

    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Du har inte loggat några resor än'
  end

  def test_renders_line_coverage_model_progress_and_highlights
    login

    Ride.create!(user: @user, tram: @tram_a1, line: 3, ridden_on: Date.today)
    Ride.create!(user: @user, tram: @tram_a1, line: 3, ridden_on: Date.today - 1)
    Ride.create!(user: @user, tram: @tram_b1, line: 4, ridden_on: Date.today - 2)

    get '/statistics'
    body = last_response.body

    assert_equal 200, last_response.status

    # line coverage: line 3 ridden twice, other lines (e.g. line 1) never ridden
    assert_includes body, 'Linje 3'
    assert_includes body, '2 resor'
    assert_includes body, 'ej riden'

    # highlight: three consecutive days (today, today-1, today-2) is a 3-day streak
    assert_includes body, '3 dagar'

    # highlight: most recent ride was today, on tram 101
    assert_includes body, 'vagn 101'

    # model completion: M29 fully ridden (1/1), M32 partially ridden (1/2)
    assert_includes body, 'M29'
    assert_includes body, 'Klart'
    assert_includes body, 'M32'
    assert_includes body, '1 / 2'

    # activity chart covers the current month
    assert_includes body, Date.today.strftime('%b')
  end
end
