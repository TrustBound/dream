-- name: list_products
-- List all products
SELECT
  id,
  name,
  price,
  stock,
  created_at
FROM products
ORDER BY id;

