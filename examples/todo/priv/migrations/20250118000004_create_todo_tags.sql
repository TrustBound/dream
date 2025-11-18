-- migration: create_todo_tags
-- created_at: 2025-01-18 00:00:04

-- +migrate up
CREATE TABLE todo_tags (
    todo_id INTEGER NOT NULL REFERENCES todos(id) ON DELETE CASCADE,
    tag_id INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (todo_id, tag_id)
);

CREATE INDEX idx_todo_tags_todo_id ON todo_tags(todo_id);
CREATE INDEX idx_todo_tags_tag_id ON todo_tags(tag_id);

-- +migrate down
DROP INDEX IF EXISTS idx_todo_tags_tag_id;
DROP INDEX IF EXISTS idx_todo_tags_todo_id;
DROP TABLE todo_tags;

