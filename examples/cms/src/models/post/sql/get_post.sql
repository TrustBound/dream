-- Get a single post by ID
SELECT id, title, content, author_id, status, created_at
FROM posts
WHERE id = $1

