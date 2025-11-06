#!/bin/bash
# Integration test script for database example

set -e

PORT=3002
BASE_URL="http://localhost:$PORT"
DB_PORT=5435

# Cleanup function to be called on exit
cleanup() {
  echo "Cleaning up..."
  kill $SERVER_PID 2>/dev/null || true
  sleep 1
  kill -9 $SERVER_PID 2>/dev/null || true
  pkill -9 -f "dream_example_database" 2>/dev/null || true
  lsof -ti:$PORT | xargs kill -9 2>/dev/null || true
  docker-compose down > /dev/null 2>&1 || true
}

# Trap EXIT to ensure cleanup happens
trap cleanup EXIT

echo "=== Setting up database ==="
cd "$(dirname "$0")"

# Stop any existing containers
docker-compose down > /dev/null 2>&1 || true

# Start database
echo "Starting PostgreSQL..."
if ! docker-compose up -d postgres > /dev/null 2>&1; then
    echo "Failed to start database"
    exit 1
fi

# Wait for database to be ready
echo "Waiting for database to be ready..."
for i in {1..30}; do
    if docker-compose exec -T postgres pg_isready -U postgres > /dev/null 2>&1; then
        echo "Database is ready!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "Database failed to start"
        docker-compose down
        exit 1
    fi
    sleep 1
done

# Run migrations (this will reset the database)
echo "Running migrations..."
export DATABASE_URL="postgres://postgres:postgres@localhost:$DB_PORT/dream_example_database_db"
# Drop and recreate database for clean slate
docker-compose exec -T postgres psql -U postgres -c "DROP DATABASE IF EXISTS dream_example_database_db;" > /dev/null 2>&1
docker-compose exec -T postgres psql -U postgres -c "CREATE DATABASE dream_example_database_db;" > /dev/null 2>&1
if ! make migrate > /dev/null 2>&1; then
    echo "Failed to run migrations"
    docker-compose down
    exit 1
fi

echo ""
echo "=== Building and starting server ==="
make clean > /dev/null 2>&1 || true
# Run with stderr/stdout captured but also displayed for errors
if ! make run > /tmp/database_test.log 2>&1 & then
    echo "Failed to start server"
    cat /tmp/database_test.log
    docker-compose down
    exit 1
fi

SERVER_PID=$!
echo "Server started (PID: $SERVER_PID)"

# Wait for server to be ready
echo "Waiting for server to be ready..."
for i in {1..30}; do
    if curl -s "$BASE_URL/users" > /dev/null 2>&1; then
        echo "Server is ready!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "Server failed to start"
        cat /tmp/database_test.log | tail -20
        kill $SERVER_PID 2>/dev/null || true
        docker-compose down
        exit 1
    fi
    sleep 1
done

echo ""
echo "=== Testing endpoints ==="

# Test GET /users (should return empty list initially)
echo -n "Testing GET /users ... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/users")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ (Status: $HTTP_CODE)"
else
    echo "✗ Expected 200, got $HTTP_CODE"
    kill $SERVER_PID 2>/dev/null || true
    docker-compose down
    exit 1
fi

# Test POST /users (create user)
echo -n "Testing POST /users ... "
RESPONSE_FILE=$(mktemp)
HTTP_CODE=$(curl -s -w "%{http_code}" -o "$RESPONSE_FILE" -X POST \
    -H "Content-Type: application/json" \
    -d '{"name":"Test User","email":"test@example.com"}' \
    "$BASE_URL/users")
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    echo "✓ (Status: $HTTP_CODE)"
    rm "$RESPONSE_FILE"
else
    echo "✗ Expected 200/201, got $HTTP_CODE"
    echo "Response body:"
    cat "$RESPONSE_FILE"
    rm "$RESPONSE_FILE"
    echo ""
    echo "Full server log (last 100 lines):"
    tail -100 /tmp/database_test.log
    kill $SERVER_PID 2>/dev/null || true
    docker-compose down
    exit 1
fi

# Test GET /users/:id (get user)
echo -n "Testing GET /users/1 ... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/users/1")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ (Status: $HTTP_CODE)"
else
    echo "✗ Expected 200, got $HTTP_CODE"
    kill $SERVER_PID 2>/dev/null || true
    docker-compose down
    exit 1
fi

# Test PUT /users/:id (update user)
echo -n "Testing PUT /users/1 ... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X PUT \
    -H "Content-Type: application/json" \
    -d '{"name":"Updated User","email":"updated@example.com"}' \
    "$BASE_URL/users/1")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ (Status: $HTTP_CODE)"
else
    echo "✗ Expected 200, got $HTTP_CODE"
    kill $SERVER_PID 2>/dev/null || true
    docker-compose down
    exit 1
fi

# Test GET /users/:user_id/posts
echo -n "Testing GET /users/1/posts ... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/users/1/posts")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ (Status: $HTTP_CODE)"
else
    echo "✗ Expected 200, got $HTTP_CODE"
    kill $SERVER_PID 2>/dev/null || true
    docker-compose down
    exit 1
fi

# Test POST /users/:user_id/posts (create post)
echo -n "Testing POST /users/1/posts ... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -d '{"title":"Test Post","content":"Test content"}' \
    "$BASE_URL/users/1/posts")
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    echo "✓ (Status: $HTTP_CODE)"
else
    echo "✗ Expected 200/201, got $HTTP_CODE"
    kill $SERVER_PID 2>/dev/null || true
    docker-compose down
    exit 1
fi

# Test DELETE /users/:id
echo -n "Testing DELETE /users/1 ... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$BASE_URL/users/1")
if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "204" ]; then
    echo "✓ (Status: $HTTP_CODE)"
else
    echo "✗ Expected 200/204, got $HTTP_CODE"
    kill $SERVER_PID 2>/dev/null || true
    docker-compose down
    exit 1
fi

echo ""
echo "=== All tests passed! ==="
exit 0

