# The requests of docs/guides/database-api.md and of the README, in that
# order, on an empty database. integration/run-scenarios.sh runs them against
# the server and compares the output with readme_output.txt.
# List users
curl http://localhost:3002/users

# Create user
curl -X POST http://localhost:3002/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Alice","email":"alice@example.com"}'

# Get specific user
curl http://localhost:3002/users/1

# List all users
curl http://localhost:3002/users

# Get a specific user
curl http://localhost:3002/users/1

# Create a user
curl -X POST http://localhost:3002/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Bob","email":"bob@example.com"}'

# Update a user
curl -X PUT http://localhost:3002/users/1 \
  -H "Content-Type: application/json" \
  -d '{"name":"Alice Updated","email":"alice.updated@example.com"}'

# Create a post
curl -X POST http://localhost:3002/users/1/posts \
  -H "Content-Type: application/json" \
  -d '{"title":"My First Post","content":"This is my first post!"}'

# List posts for a user
curl http://localhost:3002/users/1/posts

# Delete a user
curl -X DELETE http://localhost:3002/users/1

# The requests of docs/guides/database-api.md, after the ones above: users
# 1 and 2 were made, and user 1 was deleted. "echo" ends each response,
# which has no line break at its end.
echo
curl -i -X POST http://localhost:3002/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Grace","email":"grace@example.com"}'
echo
curl -i http://localhost:3002/users/3
echo
curl -i http://localhost:3002/users/1
echo
curl -i http://localhost:3002/users/abc
echo
curl -i -X POST http://localhost:3002/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Grace"}'
echo
curl -i http://localhost:3002/health
echo

# The files of the app, as docs/guides/database-api.md lists them
cd "$EXAMPLE"
find src -name "*.gleam" | sort
