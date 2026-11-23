--- migration:up
CREATE TABLE visits (
  id SERIAL PRIMARY KEY,
  path VARCHAR(255) NOT NULL,
  visited_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
--- migration:down
DROP TABLE IF EXISTS visits;
--- migration:end
