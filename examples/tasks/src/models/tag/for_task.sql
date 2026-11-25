-- returns: many Tag
SELECT
  t.id,
  t.name,
  t.color
FROM tags t
INNER JOIN task_tags tt ON t.id = tt.tag_id
WHERE tt.task_id = $1
ORDER BY t.name ASC;
