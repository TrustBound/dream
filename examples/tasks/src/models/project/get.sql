-- returns: one Project
-- not found: Project not found
SELECT
  id,
  name,
  description,
  color,
  created_at
FROM projects
WHERE id = $1;
