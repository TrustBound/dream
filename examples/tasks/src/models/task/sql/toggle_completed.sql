-- name: toggle_completed
-- Toggle the completed status of a task
UPDATE tasks
SET
  completed = NOT completed,
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

