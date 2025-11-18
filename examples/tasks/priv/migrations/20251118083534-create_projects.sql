--- migration:up
CREATE TABLE projects (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    color TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);
--- migration:down
DROP TABLE projects;
--- migration:end
