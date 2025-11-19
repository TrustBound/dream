-- name: update_task
-- Update a task
UPDATE tasks
SET
  title = $2,
  description = $3,
  completed = $4,
  priority = $5,
  due_date = $6,
  project_id = NULLIF($7, 0),
  updated_at = NOW()
WHERE id = $1
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

