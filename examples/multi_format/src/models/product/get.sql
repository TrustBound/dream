-- returns: one Product
SELECT
  id,
  name,
  price,
  stock,
  created_at
FROM products
WHERE id = $1
LIMIT 1;
