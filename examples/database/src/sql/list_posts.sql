-- List all posts for a user
SELECT id, user_id, title, content, created_at FROM posts WHERE user_id = $1 ORDER BY id





