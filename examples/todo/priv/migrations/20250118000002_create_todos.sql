-- migration: create_todos
-- created_at: 2025-01-18 00:00:02

-- +migrate up
CREATE TABLE todos (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    completed BOOLEAN NOT NULL DEFAULT FALSE,
    priority INTEGER NOT NULL DEFAULT 3,
    due_date DATE,
    position INTEGER NOT NULL DEFAULT 0,
    project_id INTEGER REFERENCES projects(id) ON DELETE SET NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_todos_project_id ON todos(project_id);
CREATE INDEX idx_todos_completed ON todos(completed);
CREATE INDEX idx_todos_position ON todos(position);

-- +migrate down
DROP INDEX IF EXISTS idx_todos_position;
DROP INDEX IF EXISTS idx_todos_completed;
DROP INDEX IF EXISTS idx_todos_project_id;
DROP TABLE todos;

