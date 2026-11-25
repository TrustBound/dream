-- returns: one User
-- unique users_email_key: Email already taken
INSERT INTO users (name, email) VALUES ($1, $2)
RETURNING id, name, email, created_at
