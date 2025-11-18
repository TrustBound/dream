-- name: get_tags_for_task
-- Get all tags for a specific task
SELECT
  t.id,
  t.name,
  t.color
FROM tags t
INNER JOIN task_tags tt ON t.id = tt.tag_id
WHERE tt.task_id = $1
ORDER BY t.name ASC;

