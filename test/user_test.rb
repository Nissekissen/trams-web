require_relative 'test_helper'

class UserTest < Minitest::Test
  def setup
    super
    @model = Model.create!(name: 'M32')
    @tram_a = Tram.create!(number: '101', model: @model)
    @tram_b = Tram.create!(number: '102', model: @model)
    @user = User.create!(name: 'Anna', email: 'anna@example.com', password: 'secret123', password_confirmation: 'secret123')
  end

  def test_ridden_tram_ids_returns_distinct_tram_ids
    Ride.create!(user: @user, tram: @tram_a, line: 1, ridden_on: Date.today)
    Ride.create!(user: @user, tram: @tram_a, line: 2, ridden_on: Date.today)
    Ride.create!(user: @user, tram: @tram_b, line: 3, ridden_on: Date.today)

    assert_equal [@tram_a.id, @tram_b.id].sort, @user.ridden_tram_ids.sort
  end

  def test_ridden_tram_ids_is_empty_for_a_user_with_no_rides
    assert_empty @user.ridden_tram_ids
  end

  def test_stats_counts_rides_lines_and_trams
    Ride.create!(user: @user, tram: @tram_a, line: 1, ridden_on: Date.today)
    Ride.create!(user: @user, tram: @tram_a, line: 1, ridden_on: Date.today - 1) # same tram+line again
    Ride.create!(user: @user, tram: @tram_b, line: 2, ridden_on: Date.today)

    stats = @user.stats

    assert_equal 3, stats[:rideCount]
    assert_equal 2, stats[:riddenLineCount]
    assert_equal 2, stats[:riddenTramCount]
    assert_equal 2, stats[:totalTramCount]
  end

  def test_stats_ridden_this_week_only_counts_rides_since_monday
    week_start = Date.today - ((Date.today.wday - 1) % 7)

    Ride.create!(user: @user, tram: @tram_a, line: 1, ridden_on: week_start)
    Ride.create!(user: @user, tram: @tram_a, line: 1, ridden_on: week_start - 7)

    assert_equal 1, @user.stats[:ridesThisWeek]
  end

  def test_generate_token_persists_a_new_random_api_token
    token = @user.generate_token

    refute_nil token
    assert_equal token, @user.reload.api_token
  end

  def test_generate_token_replaces_a_previous_token
    first_token = @user.generate_token
    second_token = @user.generate_token

    refute_equal first_token, second_token
    assert_equal second_token, @user.reload.api_token
  end

  def test_to_api_hash_shape
    Ride.create!(user: @user, tram: @tram_a, line: 1, ridden_on: Date.today)
    hash = @user.to_api_hash

    assert_equal @user.id, hash[:id]
    assert_equal @user.name, hash[:name]
    assert_equal @user.email, hash[:email]
    assert_equal [@tram_a.id], hash[:riddenTramIds]
    assert_equal @user.stats, hash[:stats]
  end

  def test_validate_email_accepts_a_well_formed_address
    assert User.validate_email('someone@example.com')
  end

  def test_validate_email_rejects_a_malformed_address
    refute User.validate_email('not-an-email')
  end
end
