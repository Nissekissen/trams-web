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

**Request flow:** all routes live in `app.rb` inside a single `TramsApp < Sinatra::Base` class. The `/admin` namespace (via `sinatra/namespace`) is guarded by a `before` filter that checks `current_user.is_admin`. A global `before` filter loads `@models = Model.includes(:trams).order(:name)` for all logged-in requests so layout partials (modal form) always have tram data.

**Auth:** session-based with bcrypt (`has_secure_password`). Helpers `current_user`, `logged_in?`, and `require_login` are defined in the `helpers` block in `app.rb`. `/login`, `/logout`, `/signup` are the auth routes. Most routes call `require_login` at the top.

**Views:** ERB templates under `views/`, one subfolder per resource. `views/layout.erb` wraps everything. Admin tram views live under `views/admin/trams/`, public browsing under `views/trams/`, auth forms under `views/auth/`.

**Database:** SQLite locally, Postgres in production (switched via `DATABASE_URL` env var in `config/environment.rb`). Schema changes always go through a new migration file in `db/migrate/` — never edit `schema.rb` directly. `rake db:migrate` also regenerates `schema.rb`.

**Domain model:**
- `Model` — a tram model type (e.g. M32, A36)
- `Tram` — a specific vehicle, belongs to a Model
- `Ride` — a user logging that they rode a specific tram on a date and line. Lines 1–12, each with a fixed color defined in `Ride::LINE_COLORS`
- `User` — has email + password_digest (bcrypt), `is_admin` boolean

**CSS:** single file at `public/css/style.css`. Uses CSS custom properties (`--color-accent`, `--color-surface`, etc.) defined in `:root`. Font stack: Space Grotesk (display), Inter (body), IBM Plex Mono (mono). Tabler Icons loaded via CDN in layout for icon use (`<i class="ti ti-*">`). No build step — plain CSS only. CSS link includes a `?v=<File.mtime>` cache-busting timestamp.

## Pages & routes

- `GET /` — dashboard: stats grid (rides, trams x/total, lines x/12), per-model progress bars
- `GET /trams` — explore page: expandable checklist rows grouped by model, game-styled model banners, lines seen per tram derived from all rides
- `GET /trams/:id` — individual tram detail page (may be deprecated in favour of the expandable rows)
- `POST /rides` — log a ride (redirects to `/`)
- `DELETE /rides/:id` — remove a ride (redirects to `/trams/:tram_id`)
- `/admin/trams` — CRUD for trams (admin only)

## Mobile UI

The app is primarily used on mobile. Layout switches at 760px:
- Desktop: left sidebar with nav + logout button
- Mobile: fixed bottom bar (`.bottom-area`) with a "Logga resa" game-style primary button above a three-item tab nav (Hem, Spårvagnar, Profil placeholder)

**Log ride modal:** a bottom-sheet modal (`#rideModal`) lives in `layout.erb` and is triggered by the mobile "Logga resa" button. Opens/closes by toggling `.ride-modal--open`. Animates with CSS transform + opacity transition.

## Design system

The app uses a "quiet logbook" aesthetic with a game/cartoon edge on interactive elements:

**Game buttons (`.btn-game`)** — reusable class with variants `.btn-game--primary` (navy), `.btn-game--secondary` (white), `.btn-game--danger` (red). Style: bold Space Grotesk, 1.5px solid dark border, 2px solid offset bottom shadow, press animation on `:active`.

**Standard buttons (`.btn`)** — plain style for admin/desktop use.

**Trams browse** — model sections have a dark navy banner (`.model-banner`, `#1C3D5A`) with progress bar, then a bordered container (`.tram-list`) holding individual `.tram-row` items with game-style borders and shadows. Rows expand inline to show description and lines seen on.
