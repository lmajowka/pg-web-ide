# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Postgres Web IDE - A Rails 8 application for browsing and editing PostgreSQL database tables in the browser. Development-only feature that blocks non-development access.

## Tech Stack

- **Backend:** Ruby 3.4.5, Rails 8.1.0.beta1, Puma
- **Frontend:** Hotwire (Turbo + Stimulus), Propshaft, Importmap (no build step)
- **Database:** PostgreSQL (development), SQLite (test/production)
- **Deployment:** Docker, Kamal

## Common Commands

```bash
# Setup & Development
./bin/setup                    # Install deps, prepare DB, start server
./bin/dev                      # Start development server (port 3000)
bin/rails console              # Interactive Rails console

# Testing
bin/rails test                 # Run all unit tests
bin/rails test:system          # Run system/E2E tests
bin/rails test test/controllers/db_ide_controller_test.rb  # Single test file

# Linting & Security
./bin/rubocop                  # Check Ruby code style
./bin/rubocop -A               # Auto-fix style issues
./bin/brakeman                 # Security static analysis
./bin/bundler-audit            # Gem vulnerability check

# CI Pipeline (runs everything)
./bin/ci                       # Setup, lint, audit, security, tests
```

## Architecture

**Request Flow:**
```
HTTP Request → Rails Router → DbIdeController → Database Operations → ERB View → Response
```

**Main Routes (`config/routes.rb`):**
- `GET /` or `/db_ide` → `db_ide#index` (list tables, show table data)
- `POST /db_ide/execute` → `db_ide#execute` (run SQL query)
- `POST /db_ide/create` → `db_ide#create` (insert row)
- `PATCH /db_ide/update` → `db_ide#update` (edit row)
- `DELETE /db_ide/destroy` → `db_ide#destroy` (delete row)

**Key Files:**
- `app/controllers/db_ide_controller.rb` - Core logic: SQL execution, CRUD operations
- `app/views/db_ide/index.html.erb` - Main UI with sidebar and table view
- `app/views/db_ide/_table.html.erb` - Table display partial with sortable columns
- `app/views/db_ide/_edit_form.html.erb` - Row create/edit form

**Database Operations:**
The controller uses raw SQL with proper parameterization (not ActiveRecord ORM) to handle any table structure. All SQL uses `connection.quote_table_name()`, `connection.quote_column_name()`, and `connection.quote()` for security.

## Environment Variables

Configure via `.env` file (see `.env.example`):
- `PG_DB`, `PG_USER`, `PG_PASSWORD`, `PG_HOST`, `PG_PORT` - PostgreSQL connection (dev only)

## Code Style

Uses `rubocop-rails-omakase` (Basecamp's opinionated style). Run `./bin/rubocop -A` before committing.
