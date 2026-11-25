-- returns: one Post
INSERT INTO posts (user_id, title, content) VALUES ($1, $2, $3)
RETURNING id, user_id, title, content, created_at
