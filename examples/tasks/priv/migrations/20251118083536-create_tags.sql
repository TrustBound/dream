--- migration:up
CREATE TABLE tags (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    color TEXT
);
--- migration:down
DROP TABLE tags;
--- migration:end
