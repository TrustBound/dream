-- name: list_tasks
-- List all tasks ordered by position
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
ORDER BY position ASC, created_at DESC;

