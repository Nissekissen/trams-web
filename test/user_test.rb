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

  def test_to_api_hash_reports_google_linked_false_when_not_linked
    refute @user.to_api_hash[:googleLinked]
  end

  def test_to_api_hash_reports_google_linked_true_when_linked
    @user.update!(google_uid: 'some-uid')
    assert @user.to_api_hash[:googleLinked]
  end

  def test_verify_google_id_token_accepts_either_the_web_or_ios_client_id_as_audience
    original_ios_client_id = ENV['GOOGLE_IOS_CLIENT_ID']
    ENV['GOOGLE_IOS_CLIENT_ID'] = 'ios-client-id'
    seen_aud = nil

    Google::Auth::IDTokens.stub(:verify_oidc, ->(_token, aud:) { seen_aud = aud; { 'email_verified' => true } }) do
      User.verify_google_id_token('fake')
    end

    assert_includes seen_aud, ENV['GOOGLE_CLIENT_ID']
    assert_includes seen_aud, 'ios-client-id'
  ensure
    ENV['GOOGLE_IOS_CLIENT_ID'] = original_ios_client_id
  end

  def test_validate_email_accepts_a_well_formed_address
    assert User.validate_email('someone@example.com')
  end

  def test_validate_email_rejects_a_malformed_address
    refute User.validate_email('not-an-email')
  end

  # --- detailed_stats -------------------------------------------------------
  # Spec for the /statistics page. Contract:
  #   { since:, total_rides:, lines: { 1..12 => { rides: } },
  #     models: [{ name:, ridden:, total: }],
  #     monthly: [{ month: (Date, 1st-of-month), rides: }] * 12, oldest first,
  #     highlights: { top_line: { line:, rides: } | nil,
  #                    longest_streak: { days:, from:, to: } | nil,
  #                    last_ride: { date:, line:, tram_number: } | nil } }

  def test_detailed_stats_returns_totals_since_date_and_line_breakdown
    Ride.create!(user: @user, tram: @tram_a, line: 3, ridden_on: Date.today)
    Ride.create!(user: @user, tram: @tram_a, line: 3, ridden_on: Date.today - 1)
    Ride.create!(user: @user, tram: @tram_b, line: 4, ridden_on: Date.today - 2)

    stats = @user.detailed_stats

    assert_equal 3, stats[:total_rides]
    assert_equal Date.today - 2, stats[:since]
    assert_equal 12, stats[:lines].size
    assert_equal 2, stats[:lines][3][:rides]
    assert_equal 1, stats[:lines][4][:rides]
    assert_equal 0, stats[:lines][1][:rides]
  end

  def test_detailed_stats_since_and_total_rides_for_a_user_with_no_rides
    stats = @user.detailed_stats

    assert_nil stats[:since]
    assert_equal 0, stats[:total_rides]
  end

  def test_detailed_stats_reports_ridden_and_total_trams_per_model
    other_model = Model.create!(name: 'M29')
    other_tram  = Tram.create!(number: '301', model: other_model)

    Ride.create!(user: @user, tram: @tram_a, line: 1, ridden_on: Date.today)
    Ride.create!(user: @user, tram: other_tram, line: 2, ridden_on: Date.today)

    models_by_name = @user.detailed_stats[:models].each_with_object({}) { |m, h| h[m[:name]] = m }

    assert_equal 1, models_by_name[@model.name][:ridden]
    assert_equal 2, models_by_name[@model.name][:total]
    assert_equal 1, models_by_name['M29'][:ridden]
    assert_equal 1, models_by_name['M29'][:total]
  end

  def test_detailed_stats_highlights_the_most_ridden_line
    Ride.create!(user: @user, tram: @tram_a, line: 3, ridden_on: Date.today)
    Ride.create!(user: @user, tram: @tram_a, line: 3, ridden_on: Date.today - 1)
    Ride.create!(user: @user, tram: @tram_b, line: 4, ridden_on: Date.today - 2)

    top_line = @user.detailed_stats[:highlights][:top_line]

    assert_equal 3, top_line[:line]
    assert_equal 2, top_line[:rides]
  end

  def test_detailed_stats_top_line_is_nil_for_a_user_with_no_rides
    assert_nil @user.detailed_stats[:highlights][:top_line]
  end

  def test_detailed_stats_highlights_the_longest_streak_of_consecutive_days
    Ride.create!(user: @user, tram: @tram_a, line: 1, ridden_on: Date.today)
    Ride.create!(user: @user, tram: @tram_a, line: 1, ridden_on: Date.today - 1)
    Ride.create!(user: @user, tram: @tram_a, line: 1, ridden_on: Date.today - 2)
    Ride.create!(user: @user, tram: @tram_b, line: 2, ridden_on: Date.today - 10) # isolated day, shorter streak

    streak = @user.detailed_stats[:highlights][:longest_streak]

    assert_equal 3, streak[:days]
    assert_equal Date.today - 2, streak[:from]
    assert_equal Date.today, streak[:to]
  end

  def test_detailed_stats_highlights_the_most_recent_ride
    Ride.create!(user: @user, tram: @tram_a, line: 1, ridden_on: Date.today - 5)
    Ride.create!(user: @user, tram: @tram_b, line: 2, ridden_on: Date.today)

    last_ride = @user.detailed_stats[:highlights][:last_ride]

    assert_equal Date.today, last_ride[:date]
    assert_equal 2, last_ride[:line]
    assert_equal @tram_b.number, last_ride[:tram_number]
  end

  def test_detailed_stats_monthly_covers_the_last_12_months_ending_this_month
    Ride.create!(user: @user, tram: @tram_a, line: 1, ridden_on: Date.today)

    monthly = @user.detailed_stats[:monthly]

    assert_equal 12, monthly.size
    assert_equal Date.today.beginning_of_month, monthly.last[:month]
    assert_equal 1, monthly.last[:rides]
  end
end
