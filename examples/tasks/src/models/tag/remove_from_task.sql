-- returns: one
-- not found: Tag not found on task
DELETE FROM task_tags
WHERE task_id = $1 AND tag_id = $2
RETURNING tag_id;
