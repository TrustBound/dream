-- returns: one Task
-- params: id, position
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
