require 'active_support/cache'

class Rack::Attack
  # Sinatra has no Rails.cache for rack-attack to auto-detect, so the
  # store has to be set explicitly. In-memory is fine here since Puma
  # runs as a single process (no `workers` configured).
  self.cache.store = ActiveSupport::Cache::MemoryStore.new

  AUTH_PATHS = ['/login', '/api/auth/login'].freeze
  GOOGLE_AUTH_PATHS = ['/auth/google', '/api/auth/google'].freeze

  throttle('logins/ip', limit: 5, period: 60) do |req|
    req.ip if req.post? && AUTH_PATHS.include?(req.path)
  end

  throttle('google-auth/ip', limit: 10, period: 60) do |req|
    req.ip if req.post? && GOOGLE_AUTH_PATHS.include?(req.path)
  end
end
