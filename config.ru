require_relative 'app'
require_relative 'api'

map '/api' do
  run TramsApi
end

map '/' do
  run TramsApp
end
