-- returns: one Project
SELECT
  id,
  name,
  description,
  color,
  created_at
FROM projects
WHERE id = $1;
