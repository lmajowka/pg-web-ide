# Postgres Web IDE

A modern Rails 8 web interface for browsing and editing PostgreSQL databases. Features table browsing, CRUD operations, SQL query runner, and AI-powered query generation. Built for development environments with security-first design.

## Requirements

- Ruby 3.4.5
- PostgreSQL

## Setup

1. Clone the repo and install dependencies:

```bash
./bin/setup
```

2. Copy the example environment file and configure your database connection:

```bash
cp .env.example .env
```

Edit `.env` with your PostgreSQL credentials:

```env
PG_DB=your_database_name
PG_USER=your_pg_user
PG_PASSWORD=your_pg_password
PG_HOST=localhost
PG_PORT=5432
OPENAI_API_KEY=your_openai_api_key
```

## Running

```bash
./bin/dev
```

The app runs at [http://localhost:3000](http://localhost:3000).

## Features

- Browse any table in the connected PostgreSQL database
- Sort, filter, and paginate rows
- Create, edit, and delete rows
- Execute raw SQL queries
- Switch between multiple databases at runtime

## Testing

```bash
bin/rails test          # Unit tests
bin/rails test:system   # System/E2E tests
```

## Linting & Security

```bash
./bin/rubocop           # Check code style
./bin/rubocop -A        # Auto-fix style issues
./bin/brakeman          # Security static analysis
./bin/bundler-audit     # Gem vulnerability check
```

## Notes

- Access is blocked in non-development environments.
- All SQL operations use parameterized queries and Rails' quoting helpers to prevent injection.
