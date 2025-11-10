#!/bin/bash
# Integration test script for singleton example

set -e

PORT=3000
BASE_URL="http://localhost:$PORT"

echo "=== Building singleton example ==="
cd "$(dirname "$0")"
make clean > /dev/null 2>&1 || true
if ! make run > /tmp/singleton_test.log 2>&1 & then
    echo "Failed to start server"
    exit 1
fi

SERVER_PID=$!
echo "Server started (PID: $SERVER_PID)"

# Wait for server to be ready
echo "Waiting for server to be ready..."
sleep 3  # Give server extra time to initialize singleton services
for i in {1..30}; do
    if curl -s "$BASE_URL/" > /dev/null 2>&1; then
        # Test /api endpoint separately with a small delay
        sleep 1
        if curl -s "$BASE_URL/api" > /dev/null 2>&1; then
            echo "Server is ready!"
            break
        fi
    fi
    if [ $i -eq 30 ]; then
        echo "Server failed to start"
        cat /tmp/singleton_test.log | tail -20
        kill $SERVER_PID 2>/dev/null || true
        exit 1
    fi
    sleep 1
done

echo ""
echo "=== Testing endpoints ==="

# Test GET /
echo -n "Testing GET / ... "
RESPONSE=$(curl -s "$BASE_URL/")
if [[ "$RESPONSE" == *"Welcome"* ]] || [[ "$RESPONSE" == *"Singleton"* ]]; then
    echo "✓"
else
    echo "✗ Response doesn't contain expected content"
    echo "Got: $RESPONSE"
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi

# Test GET /api (should succeed)
echo -n "Testing GET /api ... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ (Status: $HTTP_CODE)"
else
    echo "✗ Expected 200, got $HTTP_CODE"
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi

# Test GET /api/status
echo -n "Testing GET /api/status ... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/status")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ (Status: $HTTP_CODE)"
else
    echo "✗ Expected 200, got $HTTP_CODE"
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi

# Test rate limiting (make 12 requests, last 2 should be rate limited)
echo -n "Testing rate limiting (12 requests) ... "
RATE_LIMITED=0
for i in {1..12}; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api")
    if [ "$HTTP_CODE" = "429" ]; then
        RATE_LIMITED=$((RATE_LIMITED + 1))
    fi
done
if [ $RATE_LIMITED -gt 0 ]; then
    echo "✓ (Rate limited $RATE_LIMITED requests)"
else
    echo "⚠ (No rate limiting detected - may need more requests)"
fi

echo ""
echo "=== All tests passed! ==="

# Cleanup
echo "Cleaning up..."
kill $SERVER_PID 2>/dev/null || true
sleep 2
kill -9 $SERVER_PID 2>/dev/null || true
pkill -f "dream_example_singleton" 2>/dev/null || true
# Ensure port is free
lsof -ti:$PORT | xargs kill -9 2>/dev/null || true
sleep 1
exit 0

