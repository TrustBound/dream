#!/bin/bash
# Test an example's integration tests in CI environment

set -e

EXAMPLE_DIR="$1"
USE_CI_POSTGRES="${2:-false}"

if [ -z "$EXAMPLE_DIR" ]; then
  echo "Error: Example directory required"
  echo "Usage: $0 <example_dir> [use_ci_postgres]"
  exit 1
fi

cd "$EXAMPLE_DIR"
EXAMPLE_NAME=$(basename "$EXAMPLE_DIR")

echo "=== Testing $EXAMPLE_NAME example ==="

# Install Elixir/Mix dependencies
echo "Installing test dependencies..."
mix deps.get

# For database examples in CI, skip docker-compose
if [ "$USE_CI_POSTGRES" = "true" ]; then
  echo "Using CI PostgreSQL service..."
  
  # Build and run migrations if needed
  if [ -d "priv/migrations" ]; then
    echo "Running migrations..."
    gleam deps download
    gleam run -m cigogne all
  fi
  
  # Run tests without docker-compose
  echo "Building application..."
  gleam build
  
  # Determine port from Makefile or default
  PORT=$(grep -oP '(?<=:)\d+(?=\s|$)' Makefile | head -1 || echo "3000")
  
  echo "Starting server on port $PORT..."
  gleam run -m main > /tmp/${EXAMPLE_NAME}_test.log 2>&1 &
  SERVER_PID=$!
  echo "Server PID: $SERVER_PID"
  
  # Wait for server
  echo "Waiting for server to be ready..."
  for i in $(seq 1 30); do
    if curl -s http://localhost:${PORT} > /dev/null 2>&1; then
      echo "Server is ready!"
      break
    fi
    if [ $i -eq 30 ]; then
      echo "Server failed to start"
      tail -20 /tmp/${EXAMPLE_NAME}_test.log
      kill $SERVER_PID 2>/dev/null || true
      exit 1
    fi
    sleep 1
  done
  
  # Run tests
  echo "Running integration tests..."
  MIX_ENV=test mix test
  TEST_EXIT=$?
  
  # Cleanup
  echo "Cleaning up..."
  kill $SERVER_PID 2>/dev/null || true
  sleep 1
  kill -9 $SERVER_PID 2>/dev/null || true
  
  exit $TEST_EXIT
else
  # Local testing - use docker-compose
  echo "Running local integration tests..."
  make test-integration
fi





