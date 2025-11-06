#!/bin/bash
# Integration test script for static example

set -e

PORT=3000
BASE_URL="http://localhost:$PORT"

echo "=== Building static example ==="
cd "$(dirname "$0")"
make clean > /dev/null 2>&1 || true
if ! make run > /tmp/static_test.log 2>&1 & then
    echo "Failed to start server"
    exit 1
fi

SERVER_PID=$!
echo "Server started (PID: $SERVER_PID)"

# Wait for server to be ready
echo "Waiting for server to be ready..."
for i in {1..30}; do
    if curl -s "$BASE_URL/public/" > /dev/null 2>&1; then
        echo "Server is ready!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "Server failed to start"
        cat /tmp/static_test.log
        kill $SERVER_PID 2>/dev/null || true
        exit 1
    fi
    sleep 1
done

echo ""
echo "=== Testing endpoints ==="

# Test GET /public/ (should serve index.html)
echo -n "Testing GET /public/ ... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/public/")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ (Status: $HTTP_CODE)"
else
    echo "✗ Expected 200, got $HTTP_CODE"
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi

# Test GET /public/styles.css
echo -n "Testing GET /public/styles.css ... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/public/styles.css")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ (Status: $HTTP_CODE)"
else
    echo "✗ Expected 200, got $HTTP_CODE"
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi

# Test GET /public/images/cat.svg
echo -n "Testing GET /public/images/cat.svg ... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/public/images/cat.svg")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ (Status: $HTTP_CODE)"
else
    echo "✗ Expected 200, got $HTTP_CODE"
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi

# Test GET /assets/data.json
echo -n "Testing GET /assets/data.json ... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/assets/data.json")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ (Status: $HTTP_CODE)"
else
    echo "✗ Expected 200, got $HTTP_CODE"
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi

# Test GET /images/cat.svg (extension filter)
echo -n "Testing GET /images/cat.svg (extension filter) ... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/images/cat.svg")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ (Status: $HTTP_CODE)"
else
    echo "✗ Expected 200, got $HTTP_CODE"
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi

# Test GET /public/../../../etc/passwd (should be blocked)
echo -n "Testing GET /public/../../../etc/passwd (security) ... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/public/../../../etc/passwd")
if [ "$HTTP_CODE" = "404" ]; then
    echo "✓ (Status: $HTTP_CODE - Blocked as expected)"
else
    echo "✗ Expected 404, got $HTTP_CODE"
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi

echo ""
echo "=== All tests passed! ==="

# Cleanup
echo "Cleaning up..."
kill $SERVER_PID 2>/dev/null || true
sleep 2
kill -9 $SERVER_PID 2>/dev/null || true
pkill -f "dream_example_static" 2>/dev/null || true
# Ensure port is free
lsof -ti:$PORT | xargs kill -9 2>/dev/null || true
sleep 1
exit 0

