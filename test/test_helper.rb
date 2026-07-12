ENV['RACK_ENV'] ||= 'test'
ENV['GOOGLE_CLIENT_ID'] ||= 'test-client-id'
ENV['RESEND_TOKEN'] ||= 'test-resend-token'
ENV['APP_URL'] ||= 'example.com'

require_relative '../config/environment'
require 'minitest/autorun'
require 'rack/test'

class Minitest::Test
  def setup
    ActiveRecord::Base.connection.begin_transaction(joinable: false)
  end

  def teardown
    ActiveRecord::Base.connection.rollback_transaction
  end
end
