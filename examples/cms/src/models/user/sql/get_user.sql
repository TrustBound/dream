-- Get a single user by ID
SELECT id, username, email, created_at
FROM users
WHERE id = $1

