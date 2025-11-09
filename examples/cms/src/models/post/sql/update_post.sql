-- Update a post
UPDATE posts
SET title = $1, content = $2
WHERE id = $3
RETURNING id, title, content, author_id, status, created_at

