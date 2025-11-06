//// This module contains the code to run the sql queries defined in
//// `./src/sql`.
//// > 🐿️ This module was generated automatically using v4.5.0 of
//// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
////

import gleam/dynamic/decode
import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import pog

/// A row you get from running the `get_product` query
/// defined in `./src/sql/get_product.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.5.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type GetProductRow {
  GetProductRow(
    id: Int,
    name: String,
    price: Float,
    stock: Int,
    created_at: Option(Timestamp),
  )
}

/// name: get_product
/// Get a single product by ID
///
/// > 🐿️ This function was generated automatically using v4.5.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn get_product(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(GetProductRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use name <- decode.field(1, decode.string)
    use price <- decode.field(2, pog.numeric_decoder())
    use stock <- decode.field(3, decode.int)
    use created_at <- decode.field(4, decode.optional(pog.timestamp_decoder()))
    decode.success(GetProductRow(id:, name:, price:, stock:, created_at:))
  }

  "-- name: get_product
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

"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `list_products` query
/// defined in `./src/sql/list_products.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.5.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ListProductsRow {
  ListProductsRow(
    id: Int,
    name: String,
    price: Float,
    stock: Int,
    created_at: Option(Timestamp),
  )
}

/// name: list_products
/// List all products
///
/// > 🐿️ This function was generated automatically using v4.5.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn list_products(
  db: pog.Connection,
) -> Result(pog.Returned(ListProductsRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use name <- decode.field(1, decode.string)
    use price <- decode.field(2, pog.numeric_decoder())
    use stock <- decode.field(3, decode.int)
    use created_at <- decode.field(4, decode.optional(pog.timestamp_decoder()))
    decode.success(ListProductsRow(id:, name:, price:, stock:, created_at:))
  }

  "-- name: list_products
-- List all products
SELECT
  id,
  name,
  price,
  stock,
  created_at
FROM products
ORDER BY id;

"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}
