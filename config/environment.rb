# config/environment.rb
#
# This file is the single place that:
#   1. Loads the right gems for the current environment
#   2. Connects ActiveRecord to SQLite (dev/test) or Postgres (prod)
#   3. Loads every model
#
# Both app.rb (the web app) and Rakefile (db:setup) require this
# file first, so the database connection is always set up the same way.

require 'bundler'

APP_ENV = ENV.fetch('RACK_ENV', 'development')

require 'dotenv'
Dotenv.load(File.expand_path('../../.env', __FILE__))
ROOT    = File.expand_path('..', __dir__)

Bundler.require(:default, APP_ENV)

require 'active_record'
require 'logger'
require 'date'

ActiveRecord::Base.logger = Logger.new($stdout, level: Logger::WARN) if APP_ENV == 'development'

if ENV['DATABASE_URL']
  # Production (and anywhere else DATABASE_URL is set): Postgres.
  ActiveRecord::Base.establish_connection(ENV.fetch('DATABASE_URL'))
else
  # Local development / test: a SQLite file per environment under db/.
  ActiveRecord::Base.establish_connection(
    adapter: 'sqlite3',
    database: File.join(ROOT, 'db', "#{APP_ENV}.sqlite3")
  )
end

Dir[File.join(ROOT, 'models', '*.rb')].sort.each { |file| require file }

require_relative 'initializers/rack_attack'
