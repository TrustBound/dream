-- Create a new user
INSERT INTO users (name, email) VALUES ($1, $2) RETURNING id, name, email, created_at

