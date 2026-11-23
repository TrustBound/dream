# The requests of the README and of docs/guides/routing.md.
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

# The requests of docs/guides/routing.md. "echo" ends the response above,
# which has no line break at its end.
echo
curl -i http://localhost:3001/admin
echo
curl -i -H "Authorization: Bearer not-a-token" http://localhost:3001/admin
echo
curl -i -H "Authorization: Bearer user-token" http://localhost:3001/admin
echo
curl -i -H "Authorization: Bearer admin-token" http://localhost:3001/admin
echo

# The files of the project structure in README.md
cd "$EXAMPLE"
find src -type f | sort
