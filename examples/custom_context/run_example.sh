#!/bin/bash
# Integration test script for custom_context example

set -e

PORT=3001
BASE_URL="http://localhost:$PORT"

echo "=== Building custom_context example ==="
cd "$(dirname "$0")"
make clean > /dev/null 2>&1 || true
if ! make run > /tmp/custom_context_test.log 2>&1 & then
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

# Test GET / (public - no auth)
echo -n "Testing GET / (public) ... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ (Status: $HTTP_CODE)"
else
    echo "✗ Expected 200, got $HTTP_CODE"
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi

# Test GET /users/:id/posts/:post_id (no auth - should fail)
echo -n "Testing GET /users/1/posts/2 (no auth) ... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/users/1/posts/2")
if [ "$HTTP_CODE" = "401" ]; then
    echo "✓ (Status: $HTTP_CODE - Unauthorized as expected)"
else
    echo "✗ Expected 401, got $HTTP_CODE"
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi

# Test GET /users/:id/posts/:post_id (with user token - should succeed)
echo -n "Testing GET /users/1/posts/2 (with user token) ... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer user-token" "$BASE_URL/users/1/posts/2")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ (Status: $HTTP_CODE)"
else
    echo "✗ Expected 200, got $HTTP_CODE"
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi

# Test GET /admin (with user token - should fail)
echo -n "Testing GET /admin (with user token) ... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer user-token" "$BASE_URL/admin")
if [ "$HTTP_CODE" = "403" ]; then
    echo "✓ (Status: $HTTP_CODE - Forbidden as expected)"
else
    echo "✗ Expected 403, got $HTTP_CODE"
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi

# Test GET /admin (with admin token - should succeed)
echo -n "Testing GET /admin (with admin token) ... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer admin-token" "$BASE_URL/admin")
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ (Status: $HTTP_CODE)"
else
    echo "✗ Expected 200, got $HTTP_CODE"
    kill $SERVER_PID 2>/dev/null || true
    exit 1
fi

echo ""
echo "=== All tests passed! ==="

# Cleanup
echo "Cleaning up..."
kill $SERVER_PID 2>/dev/null || true
sleep 1
kill -9 $SERVER_PID 2>/dev/null || true
pkill -f "dream_example_custom_context" 2>/dev/null || true
exit 0

