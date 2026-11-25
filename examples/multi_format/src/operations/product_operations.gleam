//// Product operations - Business logic for product management
////
//// This module contains pure domain logic for product operations.
//// It calls the functions that dream_model generated in models/product,
//// which return data errors, and maps them to Dream errors with the texts
//// for the client.

import dream/http/error.{type Error}
import dream_postgres/client.{type Connection}
import gleam/result
import models/product.{type Product}
import utilities/response_helpers

/// Get a product by ID
pub fn get_product(db: Connection, id: Int) -> Result(Product, Error) {
  product.get(db, id)
  |> result.map_error(product_error)
}

/// List all products
pub fn list_products(db: Connection) -> Result(List(Product), Error) {
  product.list(db)
  |> result.map_error(product_error)
}

/// The Dream error of a product model error, with the texts for the client.
fn product_error(model_error: client.ModelQueryError) -> Error {
  response_helpers.model_error_to_error(
    model_error,
    not_found: "Product not found",
    conflicts: [],
  )
}
