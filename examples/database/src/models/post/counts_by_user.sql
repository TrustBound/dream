-- returns: many PostCount
-- not null: with_content
-- nullable: email
SELECT
  users.id,
  users.email,
  count(posts.id) AS posts,
  coalesce(string_agg(posts.title, ', ' ORDER BY posts.id), '') AS titles,
  sum(CASE WHEN posts.content IS NULL THEN 0 ELSE 1 END)::int AS with_content,
  max(posts.created_at) AS last_post_at
FROM users
LEFT JOIN posts ON posts.user_id = users.id
GROUP BY users.id, users.email
ORDER BY users.id
