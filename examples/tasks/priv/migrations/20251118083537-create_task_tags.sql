--- migration:up
CREATE TABLE task_tags (
    task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    tag_id INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (task_id, tag_id)
);

CREATE INDEX idx_task_tags_task_id ON task_tags(task_id);
CREATE INDEX idx_task_tags_tag_id ON task_tags(tag_id);
--- migration:down
DROP INDEX IF EXISTS idx_task_tags_tag_id;
DROP INDEX IF EXISTS idx_task_tags_task_id;
DROP TABLE task_tags;
--- migration:end
