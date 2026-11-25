-- returns: one Post
-- not found: Post not found
SELECT id, user_id, title, content, created_at FROM posts WHERE id = $1
