# Trams

Track the trams you've ridden in Gothenburg. Log rides, collect vehicles, complete model sets, cover all 12 lines.

Built with Ruby and Sinatra. Mobile-first, no tracking, open source.

## Stack

- **Ruby / Sinatra** — single-file app, no Rails
- **ActiveRecord** — migrations in `db/migrate/`, SQLite locally, Postgres in production
- **ERB** — server-rendered templates, no frontend framework
- **Plain CSS** — no build step

## Getting started

Requires Ruby 3.1+.

```bash
bundle install
rake db:migrate
rake dev          # starts server on port 3000 with auto-restart
```

Open `http://localhost:3000`.

## Environment variables

| Variable | Required | Description |
|---|---|---|
| `DATABASE_URL` | Production | Postgres connection string. If unset, SQLite is used. |
| `SESSION_SECRET` | Production | Secret key for cookie signing. |
| `RACK_ENV` | Production | Set to `production`. |

## Docker

```bash
docker compose up --build
```

## Database

```bash
rake db:migrate       # apply pending migrations
rake db:rollback      # roll back the last migration
```

Schema changes always go through a new file in `db/migrate/` — never edit `schema.rb` directly.

## Project structure

```
app.rb                    All routes (single Sinatra::Base class)
config/environment.rb     Database connection and model loading
models/                   ActiveRecord models
views/                    ERB templates, one subfolder per resource
public/css/style.css      Stylesheet
db/migrate/               Migrations
db/schema.rb              Auto-generated — do not edit directly
```

## License

MIT © Nils Lindblad
