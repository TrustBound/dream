-- migration: create_tags
-- created_at: 2025-01-18 00:00:03

-- +migrate up
CREATE TABLE tags (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    color TEXT
);

-- +migrate down
DROP TABLE tags;

