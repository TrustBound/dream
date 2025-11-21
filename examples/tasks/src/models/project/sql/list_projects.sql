-- name: list_projects
-- List all projects
SELECT
  id,
  name,
  description,
  color,
  created_at
FROM projects
ORDER BY created_at DESC;

