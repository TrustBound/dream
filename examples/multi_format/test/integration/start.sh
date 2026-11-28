# Starts the server as the README says. integration/run-scenarios.sh runs
# this from the repository root for the HTTP/1.1 run.
cd examples/multi_format

# Start database
make db-up

# Run migrations
make migrate

# Run the server
make run
