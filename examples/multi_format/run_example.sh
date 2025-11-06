#!/bin/bash
# Integration test script for multi_format example

set -e

PORT=3000
BASE_URL="http://localhost:$PORT"
DB_PORT=5436

# Cleanup function to be called on exit
cleanup() {
  echo "Cleaning up..."
  kill $SERVER_PID 2>/dev/null || true
  sleep 1
  kill -9 $SERVER_PID 2>/dev/null || true
  pkill -9 -f "dream_example_multi_format" 2>/dev/null || true
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
export DATABASE_URL="postgres://postgres:postgres@localhost:$DB_PORT/dream_example_multi_format_db"
# Drop and recreate database for clean slate
docker-compose exec -T postgres psql -U postgres -c "DROP DATABASE IF EXISTS dream_example_multi_format_db;" > /dev/null 2>&1
docker-compose exec -T postgres psql -U postgres -c "CREATE DATABASE dream_example_multi_format_db;" > /dev/null 2>&1
if ! make migrate > /dev/null 2>&1; then
    echo "Failed to run migrations"
    docker-compose down
    exit 1
fi

echo ""
echo "=== Building and starting server ==="
make clean > /dev/null 2>&1 || true
if ! make run > /tmp/multi_format_test.log 2>&1 & then
    echo "Failed to start server"
    docker-compose down
    exit 1
fi

SERVER_PID=$!
echo "Server started (PID: $SERVER_PID)"

# Wait for server to be ready
echo "Waiting for server to be ready..."
for i in {1..30}; do
    if curl -s "$BASE_URL/products" > /dev/null 2>&1; then
        echo "Server is ready!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "Server failed to start"
        cat /tmp/multi_format_test.log | tail -20
        kill $SERVER_PID 2>/dev/null || true
        docker-compose down
        exit 1
    fi
    sleep 1
done

echo ""
echo "=== Testing endpoints ==="

# Test GET /products (should return list - may be empty)
echo -n "Testing GET /products ... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/products")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ (Status: $HTTP_CODE)"
else
    echo "✗ Expected 200, got $HTTP_CODE"
    echo "Checking server logs..."
    cat /tmp/multi_format_test.log | tail -20
    kill $SERVER_PID 2>/dev/null || true
    docker-compose down
    exit 1
fi

# Test GET /products/1 (should work if products exist from migration)
echo -n "Testing GET /products/1 ... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/products/1")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ (Status: $HTTP_CODE)"
elif [ "$HTTP_CODE" = "404" ]; then
    echo "⚠ (Status: $HTTP_CODE - No products found, but endpoint works)"
else
    echo "✗ Expected 200 or 404, got $HTTP_CODE"
    kill $SERVER_PID 2>/dev/null || true
    docker-compose down
    exit 1
fi

# Test GET /products.json (JSON format)
echo -n "Testing GET /products.json ... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/products.json")
CONTENT_TYPE=$(curl -s -o /dev/null -w "%{content_type}" "$BASE_URL/products.json")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ (Status: $HTTP_CODE, Content-Type: $CONTENT_TYPE)"
else
    echo "✗ Expected 200, got $HTTP_CODE"
    kill $SERVER_PID 2>/dev/null || true
    docker-compose down
    exit 1
fi

# Test GET /products/1.json (JSON format)
echo -n "Testing GET /products/1.json ... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/products/1.json")
CONTENT_TYPE=$(curl -s -o /dev/null -w "%{content_type}" "$BASE_URL/products/1.json")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ (Status: $HTTP_CODE, Content-Type: $CONTENT_TYPE)"
elif [ "$HTTP_CODE" = "404" ]; then
    echo "⚠ (Status: $HTTP_CODE - No products found, but endpoint works)"
else
    echo "✗ Expected 200 or 404, got $HTTP_CODE"
    kill $SERVER_PID 2>/dev/null || true
    docker-compose down
    exit 1
fi

# Test GET /products/1.htmx (HTMX format)
echo -n "Testing GET /products/1.htmx ... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/products/1.htmx")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ (Status: $HTTP_CODE)"
elif [ "$HTTP_CODE" = "404" ]; then
    echo "⚠ (Status: $HTTP_CODE - No products found, but endpoint works)"
else
    echo "✗ Expected 200 or 404, got $HTTP_CODE"
    kill $SERVER_PID 2>/dev/null || true
    docker-compose down
    exit 1
fi

# Test GET /products/1.csv (CSV format)
echo -n "Testing GET /products/1.csv ... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/products/1.csv")
CONTENT_TYPE=$(curl -s -o /dev/null -w "%{content_type}" "$BASE_URL/products/1.csv")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ (Status: $HTTP_CODE, Content-Type: $CONTENT_TYPE)"
elif [ "$HTTP_CODE" = "404" ]; then
    echo "⚠ (Status: $HTTP_CODE - No products found, but endpoint works)"
else
    echo "✗ Expected 200 or 404, got $HTTP_CODE"
    kill $SERVER_PID 2>/dev/null || true
    docker-compose down
    exit 1
fi

# Test GET /products.csv (streaming CSV)
echo -n "Testing GET /products.csv (streaming) ... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/products.csv")
CONTENT_TYPE=$(curl -s -o /dev/null -w "%{content_type}" "$BASE_URL/products.csv")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ (Status: $HTTP_CODE, Content-Type: $CONTENT_TYPE)"
else
    echo "✗ Expected 200, got $HTTP_CODE"
    kill $SERVER_PID 2>/dev/null || true
    docker-compose down
    exit 1
fi

echo ""
echo "=== All tests passed! ==="
exit 0

