-- name: create_task
-- Create a new task
INSERT INTO tasks (
  title,
  description,
  completed,
  priority,
  due_date,
  position,
  project_id
)
VALUES ($1, $2, $3, $4, $5, $6, NULLIF($7, 0))
RETURNING
  id,
  title,
  description,
  completed,
  priority,
  due_date,
  position,
  project_id,
  created_at,
  updated_at;

