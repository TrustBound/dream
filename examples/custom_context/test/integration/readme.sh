# The requests of the README and of docs/learn/03-adding-auth.md.
# integration/run-scenarios.sh runs them against the server and compares the
# output with readme_output.txt.
# Public endpoint (no auth needed)
curl http://localhost:3001/

# Protected endpoint (needs token)
curl -H "Authorization: Bearer user-token" \
  http://localhost:3001/users/1/posts/2

# Admin endpoint (needs admin token)
curl -H "Authorization: Bearer admin-token" \
  http://localhost:3001/admin

# Try without token (will get 401 Unauthorized)
curl http://localhost:3001/users/1/posts/2

# Try regular user on admin endpoint (will get 403 Forbidden)
curl -H "Authorization: Bearer user-token" \
  http://localhost:3001/admin

# Public route - succeeds
curl http://localhost:3001/

# Without token - fails with 401
curl http://localhost:3001/users/1/posts/2

# With valid token - succeeds
curl http://localhost:3001/users/1/posts/2 \
  -H "Authorization: Bearer user-token"

# User token on the admin route - fails with 403
curl http://localhost:3001/admin \
  -H "Authorization: Bearer user-token"

# Admin token on the admin route - succeeds
curl http://localhost:3001/admin \
  -H "Authorization: Bearer admin-token"
