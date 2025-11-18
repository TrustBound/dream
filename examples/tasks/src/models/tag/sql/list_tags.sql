-- name: list_tags
-- List all tags
SELECT
  id,
  name,
  color
FROM tags
ORDER BY name ASC;

