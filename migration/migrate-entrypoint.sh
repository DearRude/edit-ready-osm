#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# Start PostgreSQL in the background using the original entrypoint script
# Capture the PID of the background process
/usr/local/bin/docker-entrypoint.sh postgres &
POSTGRES_PID=$!

echo "Waiting for PostgreSQL to start..."
# Wait for PostgreSQL to be ready to accept connections
# Use pg_isready (requires postgresql-client)
until pg_isready -h localhost -p 5432 -U "$POSTGRES_USER"; do
  echo >&2 "Postgres is unavailable - sleeping"
  sleep 1
done

echo >&2 "Postgres is up - executing command"

# Navigate to the Rails app directory
cd /openstreetmap-website

echo "Creating database (if it doesn't exist)..."
# Use the production environment as defined in database.yml
# Handle potential errors if DB already exists gracefully
bundle exec rails db:create RAILS_ENV=production || echo "Database likely already exists, continuing..."

echo "Running database migrations..."
bundle exec rails db:migrate RAILS_ENV=production

echo "Migrations finished."

# Stop PostgreSQL gracefully
echo "Stopping PostgreSQL server (PID $POSTGRES_PID)..."
# Send SIGTERM to the PostgreSQL server process started by docker-entrypoint.sh
# kill -SIGTERM "$POSTGRES_PID" # This might kill the entrypoint script, not postgres itself
# Use pg_ctl to stop the server properly
gosu postgres pg_ctl stop -D "$PGDATA" -m fast

# Wait for the background process to finish
wait $POSTGRES_PID

echo "PostgreSQL stopped."
exit 0