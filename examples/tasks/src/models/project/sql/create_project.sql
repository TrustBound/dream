-- name: create_project
-- Create a new project
INSERT INTO projects (name, description, color)
VALUES ($1, $2, $3)
RETURNING
  id,
  name,
  description,
  color,
  created_at;

