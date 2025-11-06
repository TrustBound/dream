--- migration:up
CREATE TABLE products (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  price DECIMAL(10, 2) NOT NULL,
  stock INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO products (name, price, stock) VALUES
  ('Laptop', 999.99, 15),
  ('Mouse', 29.99, 50),
  ('Keyboard', 79.99, 30),
  ('Monitor', 299.99, 20);

--- migration:down
DROP TABLE IF EXISTS products;

--- migration:end