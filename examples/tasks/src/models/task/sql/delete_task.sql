-- name: delete_task
-- Delete a task by ID
DELETE FROM tasks
WHERE id = $1;

