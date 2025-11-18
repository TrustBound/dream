#!/bin/bash
# Integration test script for task example

set -e

PORT=3000
BASE_URL="http://localhost:$PORT"
DB_PORT=5437

# Cleanup function to be called on exit
cleanup() {
  echo "Cleaning up..."
  kill $SERVER_PID 2>/dev/null || true
  sleep 1
  kill -9 $SERVER_PID 2>/dev/null || true
  pkill -9 -f "todo_example" 2>/dev/null || true
  lsof -ti:$PORT | xargs kill -9 2>/dev/null || true
  docker-compose down > /dev/null 2>&1 || true
}

# Trap EXIT to ensure cleanup happens
trap cleanup EXIT

echo "=== Setting up database ==="
cd "$(dirname "$0")"

# Stop any existing containers and clean up
docker-compose down -v > /dev/null 2>&1 || true
sleep 1

# Start database
echo "Starting PostgreSQL..."
if ! docker-compose up -d postgres > /dev/null 2>&1; then
    echo "Failed to start database"
    docker-compose down > /dev/null 2>&1 || true
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

# Run migrations
echo "Running migrations..."
export DATABASE_URL="postgres://postgres:postgres@localhost:$DB_PORT/todo_db"
# Drop and recreate database for clean slate
docker-compose exec -T postgres psql -U postgres -c "DROP DATABASE IF EXISTS todo_db;" > /dev/null 2>&1
docker-compose exec -T postgres psql -U postgres -c "CREATE DATABASE todo_db;" > /dev/null 2>&1
if ! make migrate > /dev/null 2>&1; then
    echo "Failed to run migrations"
    docker-compose down
    exit 1
fi

# Generate SQL code with Squirrel
echo "Generating SQL code..."
if ! make squirrel > /dev/null 2>&1; then
    echo "Failed to generate SQL code"
    docker-compose down
    exit 1
fi

# Compile matcha templates
echo "Compiling matcha templates..."
if ! make matcha > /dev/null 2>&1; then
    echo "Failed to compile matcha templates"
    docker-compose down
    exit 1
fi

echo ""
echo "=== Building and starting server ==="
make clean > /dev/null 2>&1 || true
# Run with stderr/stdout captured but also displayed for errors
if ! make run > /tmp/todo_test.log 2>&1 & then
    echo "Failed to start server"
    cat /tmp/todo_test.log
    docker-compose down
    exit 1
fi

SERVER_PID=$!
echo "Server started (PID: $SERVER_PID)"

# Wait for server to be ready
echo "Waiting for server to be ready..."
for i in {1..30}; do
    if curl -s "$BASE_URL/" > /dev/null 2>&1; then
        echo "Server is ready!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "Server failed to start"
        cat /tmp/todo_test.log | tail -20
        kill $SERVER_PID 2>/dev/null || true
        docker-compose down
        exit 1
    fi
    sleep 1
done

echo ""
echo "=== Testing endpoints ==="

# Test GET / (main page)
echo -n "Testing GET / ... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ (Status: $HTTP_CODE)"
else
    echo "✗ Expected 200, got $HTTP_CODE"
    cat /tmp/todo_test.log | tail -20
    kill $SERVER_PID 2>/dev/null || true
    docker-compose down
    exit 1
fi

# Test POST /tasks (create task)
echo -n "Testing POST /tasks ... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -d '{"title":"Test Task","description":"Test description","completed":false,"priority":3}' \
    "$BASE_URL/tasks")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ (Status: $HTTP_CODE)"
else
    echo "✗ Expected 200, got $HTTP_CODE"
    cat /tmp/todo_test.log | tail -20
    kill $SERVER_PID 2>/dev/null || true
    docker-compose down
    exit 1
fi

# Test GET /tasks/1.htmx (HTMX partial)
echo -n "Testing GET /tasks/1.htmx ... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/tasks/1.htmx")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ (Status: $HTTP_CODE)"
else
    echo "✗ Expected 200, got $HTTP_CODE"
    kill $SERVER_PID 2>/dev/null || true
    docker-compose down
    exit 1
fi

# Test POST /tasks/1/toggle.htmx (toggle completion)
echo -n "Testing POST /tasks/1/toggle.htmx ... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/tasks/1/toggle.htmx")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ (Status: $HTTP_CODE)"
else
    echo "✗ Expected 200, got $HTTP_CODE"
    kill $SERVER_PID 2>/dev/null || true
    docker-compose down
    exit 1
fi

# Test DELETE /tasks/1 (delete task)
echo -n "Testing DELETE /tasks/1 ... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$BASE_URL/tasks/1")
if [ "$HTTP_CODE" = "204" ]; then
    echo "✓ (Status: $HTTP_CODE)"
else
    echo "✗ Expected 204, got $HTTP_CODE"
    kill $SERVER_PID 2>/dev/null || true
    docker-compose down
    exit 1
fi

# Test GET /projects (list projects)
echo -n "Testing GET /projects ... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/projects")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ (Status: $HTTP_CODE)"
else
    echo "✗ Expected 200, got $HTTP_CODE"
    kill $SERVER_PID 2>/dev/null || true
    docker-compose down
    exit 1
fi

echo ""
echo "=== All tests passed! ==="
echo ""
echo "Server is still running at $BASE_URL"
echo "Press Ctrl+C to stop."
echo ""

# Wait for user to stop the server
wait $SERVER_PID

