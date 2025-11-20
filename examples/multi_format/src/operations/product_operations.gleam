//// Product operations - Business logic for product management
////
//// This module contains pure domain logic for product operations.
//// It returns Result types with dream.Error.

import dream/http/error.{type Error}
import dream_postgres/client.{type Connection}
import models/product as product_model
import types/product.{type Product}

/// Get a product by ID
pub fn get_product(db: Connection, id: Int) -> Result(Product, Error) {
  product_model.get(db, id)
}

/// List all products
pub fn list_products(db: Connection) -> Result(List(Product), Error) {
  product_model.list(db)
}

