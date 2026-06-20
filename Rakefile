# Rakefile
#
# Standard ActiveRecord migration workflow: each schema change lives as
# its own file in db/migrate/, applied incrementally and tracked in the
# database's own schema_migrations table. `db:migrate` only runs files it
# hasn't seen before, so it's safe to run against a database that already
# has data — unlike a full rebuild, it never drops a table you didn't
# just add a migration for.

require_relative 'config/environment'

MIGRATIONS_PATH = File.join(ROOT, 'db', 'migrate')

desc 'Start dev server with auto-restart on file changes'
task :dev do
  exec 'bundle exec rerun -- rackup -p 3000 -o 0.0.0.0'
end

namespace :db do
  desc 'Apply any pending migrations in db/migrate, then refresh db/schema.rb'
  task :migrate do
    ActiveRecord::MigrationContext.new(MIGRATIONS_PATH).migrate
    Rake::Task['db:schema:dump'].invoke
    puts "Databasen är uppdaterad (#{APP_ENV})."
  end

  desc 'Roll back the most recently applied migration, then refresh db/schema.rb'
  task :rollback do
    ActiveRecord::MigrationContext.new(MIGRATIONS_PATH).rollback
    Rake::Task['db:schema:dump'].invoke
    puts "Senaste migreringen återställd (#{APP_ENV})."
  end

  namespace :schema do
    desc 'Write the current database structure to db/schema.rb'
    task :dump do
      File.open(File.join(ROOT, 'db', 'schema.rb'), 'w') do |file|
        ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection_pool, file)
      end
    end

    desc 'Build a fresh database straight from db/schema.rb (fast, skips db/migrate — never run against data you care about)'
    task :load do
      load File.join(ROOT, 'db', 'schema.rb')
      puts "Databasen skapad från schema.rb (#{APP_ENV})."
    end
  end
end
