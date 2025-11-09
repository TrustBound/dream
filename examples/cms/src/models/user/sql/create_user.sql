-- Create a new user
INSERT INTO users (username, email)
VALUES ($1, $2)
RETURNING id, username, email, created_at

