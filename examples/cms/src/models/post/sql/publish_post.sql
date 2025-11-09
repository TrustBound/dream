-- Publish a post
UPDATE posts
SET status = 'published'
WHERE id = $1
RETURNING id, title, content, author_id, status, created_at

