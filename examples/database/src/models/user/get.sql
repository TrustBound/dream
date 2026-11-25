-- returns: one User
-- not found: User not found
SELECT id, name, email, created_at FROM users WHERE id = $1
