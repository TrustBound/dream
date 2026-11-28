-- name: get_product
-- Get a single product by ID
SELECT
  id,
  name,
  price,
  stock,
  created_at
FROM products
WHERE id = $1
LIMIT 1;

