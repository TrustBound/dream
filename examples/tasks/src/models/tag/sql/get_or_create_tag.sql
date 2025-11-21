-- name: get_or_create_tag
-- Get or create a tag by name
INSERT INTO tags (name, color)
VALUES ($1, $2)
ON CONFLICT (name) DO UPDATE SET name = EXCLUDED.name
RETURNING
  id,
  name,
  color;

