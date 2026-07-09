require_relative 'app'
require_relative 'api'

use Rack::Attack

map '/api' do
  run TramsApi
end

map '/' do
  run TramsApp
end
