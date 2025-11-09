-- Create a new post
INSERT INTO posts (title, content, author_id, status)
VALUES ($1, $2, $3, 'draft')
RETURNING id, title, content, author_id, status, created_at

