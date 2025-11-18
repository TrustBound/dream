-- name: update_position
-- Update the position of a task for drag-and-drop reordering
UPDATE tasks
SET position = $2
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

