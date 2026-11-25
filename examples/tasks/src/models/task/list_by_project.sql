-- returns: many Task
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
WHERE project_id = $1
ORDER BY position ASC, created_at DESC;
