-- returns: one User
-- unique: users_email_key
INSERT INTO users (name, email) VALUES ($1, $2)
RETURNING id, name, email, created_at
