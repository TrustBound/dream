-- name: remove_tag_from_task
-- Remove a tag from a task
DELETE FROM task_tags
WHERE task_id = $1 AND tag_id = $2;

