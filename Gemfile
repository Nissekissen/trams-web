source 'https://rubygems.org'

ruby '>= 3.1'

gem 'sinatra', '~> 4.0'
gem 'dotenv', '~> 3.1'
gem 'activerecord', '~> 7.1'
gem 'rake', '~> 13.0'
gem 'rackup', '~> 2.1'
gem 'puma', '~> 6.4'

# Ruby 3.4+ dropped these from the default standard library. ActiveSupport
# (a dependency of ActiveRecord) still expects to be able to require them,
# so they're listed explicitly to avoid a "cannot load such file" error on
# newer Ruby versions.
gem 'mutex_m'
gem 'base64'

group :development, :test do
  gem 'sqlite3', '~> 1.7'
  gem 'rerun', '~> 0.14'
end

group :production do
  gem 'pg', '~> 1.5'
end
