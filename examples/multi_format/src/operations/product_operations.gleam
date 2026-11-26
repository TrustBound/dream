//// Product operations - Business logic for product management
////
//// This module contains pure domain logic for product operations.
//// It calls the functions that dream_model generated in models/product,
//// which return data errors, and maps them to Dream errors with the texts
//// for the client.

import dream/http/error.{type Error, NotFound, from_shared}
import dream_errors
import dream_postgres/client.{type Connection, type QueryError}
import gleam/result.{map_error}
import models/product.{type Product, get, list}

/// Get a product by ID
pub fn get_product(db: Connection, id: Int) -> Result(Product, Error) {
  get(db, id)
  |> map_error(product_error)
}

/// List all products
pub fn list_products(db: Connection) -> Result(List(Product), Error) {
  list(db)
  |> map_error(product_error)
}

/// The Dream error of a model error. A missing row keeps its own text.
/// Every other error goes through `error.from_shared`, which never shows
/// the developer message of the model error.
fn product_error(model_error: dream_errors.Error(QueryError)) -> Error {
  case model_error {
    dream_errors.NotFound(..) -> NotFound("Product not found")
    _ -> from_shared(model_error)
  }
}
