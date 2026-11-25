-- returns: one Task
-- not found: Task not found
SELECT
  id,
  title,
  description,
  completed,
  priority,
  due_date,
  position,
  project_id,
  created_at,
  updated_at
FROM tasks
WHERE id = $1;
