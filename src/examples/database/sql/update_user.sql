-- Update a user
UPDATE users SET name = $1, email = $2 WHERE id = $3 RETURNING id, name, email, created_at




