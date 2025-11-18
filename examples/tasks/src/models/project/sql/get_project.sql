-- name: get_project
-- Get a single project by ID
SELECT
  id,
  name,
  description,
  color,
  created_at
FROM projects
WHERE id = $1;

