# The requests of docs/learn/02-building-api.md and of the README, in that
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
