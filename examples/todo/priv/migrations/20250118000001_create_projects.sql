-- migration: create_projects
-- created_at: 2025-01-18 00:00:01

-- +migrate up
CREATE TABLE projects (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    color TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- +migrate down
DROP TABLE projects;

