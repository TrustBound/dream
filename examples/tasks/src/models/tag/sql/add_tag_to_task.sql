-- name: add_tag_to_task
-- Add a tag to a task
INSERT INTO task_tags (task_id, tag_id)
VALUES ($1, $2)
ON CONFLICT (task_id, tag_id) DO NOTHING;

