#!/bin/bash
# Integration test script for simple example

set -e

PORT=3000
BASE_URL="http://localhost:$PORT"

echo "=== Building simple example ==="
cd "$(dirname "$0")"
make clean > /dev/null 2>&1 || true
if ! make run > /tmp/simple_test.log 2>&1 & then
    echo "Failed to start server"
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
if [[ "$RESPONSE" == *"Hello, World!"* ]]; then
    echo "✓"
else
    echo "✗ Expected 'Hello, World!', got: $RESPONSE"
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi

# Test GET /users/:id/posts/:post_id
echo -n "Testing GET /users/1/posts/2 ... "
RESPONSE=$(curl -s "$BASE_URL/users/1/posts/2")
if [[ "$RESPONSE" == *"User: 1"* ]] && [[ "$RESPONSE" == *"Post: 2"* ]]; then
    echo "✓"
else
    echo "✗ Response doesn't contain expected content"
    echo "Response: $RESPONSE"
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
pkill -f "dream_example_simple" 2>/dev/null || true
# Ensure port is free
lsof -ti:$PORT | xargs kill -9 2>/dev/null || true
sleep 1
exit 0

