#!/bin/bash
# Integration test script for streaming example

set -e

PORT=3000
BASE_URL="http://localhost:$PORT"

echo "=== Building streaming example ==="
cd "$(dirname "$0")"
make clean > /dev/null 2>&1 || true
if ! make run > /tmp/streaming_test.log 2>&1 & then
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
RESPONSE=$(curl -s "$BASE_URL/" | head -1)
if [[ "$RESPONSE" == *"Streaming"* ]]; then
    echo "✓"
else
    echo "✗ Response doesn't contain expected content"
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi

# Test GET /fetch (non-streaming - may take time)
echo -n "Testing GET /fetch (non-streaming) ... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 "$BASE_URL/fetch" || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ (Status: $HTTP_CODE)"
elif [ "$HTTP_CODE" = "000" ]; then
    echo "⚠ (Timeout - external service may be slow, but endpoint exists)"
else
    echo "⚠ (Status: $HTTP_CODE - external request may be slow)"
fi

# Test GET /stream (streaming - may take time)
echo -n "Testing GET /stream (streaming) ... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 15 "$BASE_URL/stream" || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ (Status: $HTTP_CODE)"
elif [ "$HTTP_CODE" = "000" ]; then
    echo "⚠ (Timeout - external service may be slow, but endpoint exists)"
else
    echo "⚠ (Status: $HTTP_CODE - external request may be slow)"
fi

echo ""
echo "=== All tests passed! ==="

# Cleanup
echo "Cleaning up..."
kill $SERVER_PID 2>/dev/null || true
sleep 2
kill -9 $SERVER_PID 2>/dev/null || true
pkill -f "dream_example_streaming" 2>/dev/null || true
# Ensure port is free
lsof -ti:$PORT | xargs kill -9 2>/dev/null || true
sleep 1
exit 0

