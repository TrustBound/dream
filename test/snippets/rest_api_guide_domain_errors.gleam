//// REST API guide: domain errors
////
//// A model function that returns Dream's `Error` type, as shown in
//// docs/guides/rest-api.md.

import dream/http/error.{type Error, NotFound}

pub type Product {
  Product(id: Int, name: String)
}

// Use Dream's Error type instead of custom error types.
// This keeps error handling consistent across the application.
pub fn find_product(
  products: List(Product),
  id: Int,
) -> Result(Product, Error) {
  case products {
    [] -> Error(NotFound("Product not found"))
    [product, ..] if product.id == id -> Ok(product)
    [_product, ..rest] -> find_product(rest, id)
  }
}
