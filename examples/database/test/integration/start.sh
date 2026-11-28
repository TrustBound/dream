# Starts the server as the README says. integration/run-scenarios.sh runs
# this from the repository root for the HTTP/1.1 run.
cd examples/database

# Start PostgreSQL database
make db-up

# Run database migrations
make migrate

# Start the server
make run
