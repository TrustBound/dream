-- returns: one Tag
INSERT INTO tags (name, color)
VALUES ($1, $2)
ON CONFLICT (name) DO UPDATE SET name = EXCLUDED.name
RETURNING
  id,
  name,
  color;
