-- returns: one
-- not found: Task not found
DELETE FROM tasks
WHERE id = $1
RETURNING id;
