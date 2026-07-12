require 'active_support/cache'

class Rack::Attack
  # Sinatra has no Rails.cache for rack-attack to auto-detect, so the
  # store has to be set explicitly. In-memory is fine here since Puma
  # runs as a single process (no `workers` configured).
  self.cache.store = ActiveSupport::Cache::MemoryStore.new

  # Throttling is real request-rate protection, not app logic under test —
  # without this, the test suite trips the login throttle after a handful
  # of auth tests and every later test in the run gets a false 403.
  self.enabled = false if APP_ENV == 'test'

  AUTH_PATHS = ['/login', '/api/auth/login'].freeze
  GOOGLE_AUTH_PATHS = ['/auth/google', '/api/auth/google'].freeze

  throttle('logins/ip', limit: 5, period: 60) do |req|
    req.ip if req.post? && AUTH_PATHS.include?(req.path)
  end

  throttle('google-auth/ip', limit: 10, period: 60) do |req|
    req.ip if req.post? && GOOGLE_AUTH_PATHS.include?(req.path)
  end
end
