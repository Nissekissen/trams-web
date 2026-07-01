# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
bundle install          # install dependencies
rake db:migrate         # run pending migrations and regenerate schema.rb
rake db:rollback        # roll back the last migration
rake dev                # start dev server with auto-restart (port 3000)
bundle exec rackup -p 4567  # start dev server manually

rake users:backfill_auth    # backfill placeholder email/password for existing users
rake "trams:bulk_add[501,530,M32]"  # bulk-create trams for a model
```

No test suite exists yet.

## Architecture

Single-file Sinatra app (`app.rb`) using ActiveRecord without Rails. The entry point is `config.ru` → `app.rb` → `config/environment.rb` (DB connection + model loading).

**Request flow:** all routes live in `app.rb` inside a single `TramsApp < Sinatra::Base` class. The `/admin` namespace (via `sinatra/namespace`) is guarded by a `before` filter that checks `current_user.is_admin`.

**Auth:** session-based with bcrypt (`has_secure_password`). Helpers `current_user`, `logged_in?`, and `require_login` are defined in the `helpers` block in `app.rb`. `/login`, `/logout`, `/signup` are the auth routes. Most routes call `require_login` at the top.

**Views:** ERB templates under `views/`, one subfolder per resource. `views/layout.erb` wraps everything. Admin tram views live under `views/admin/trams/`, public browsing under `views/trams/`, auth forms under `views/auth/`.

**Database:** SQLite locally, Postgres in production (switched via `DATABASE_URL` env var in `config/environment.rb`). Schema changes always go through a new migration file in `db/migrate/` — never edit `schema.rb` directly. `rake db:migrate` also regenerates `schema.rb`.

**Domain model:**
- `Model` — a tram model type (e.g. M32, A36)
- `Tram` — a specific vehicle, belongs to a Model
- `Ride` — a user logging that they rode a specific tram on a date and line. Lines 1–12, each with a fixed color defined in `Ride::LINE_COLORS`
- `User` — has email + password_digest (bcrypt), `is_admin` boolean

**CSS:** single file at `public/css/style.css`. Uses CSS custom properties (`--color-accent`, `--color-surface`, etc.) defined in `:root`. Font stack: Space Grotesk (display), Inter (body), IBM Plex Mono (mono). No build step — plain CSS only.
