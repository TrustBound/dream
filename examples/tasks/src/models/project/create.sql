-- returns: one Project
INSERT INTO projects (name, description, color)
VALUES ($1, $2, $3)
RETURNING
  id,
  name,
  description,
  color,
  created_at;
