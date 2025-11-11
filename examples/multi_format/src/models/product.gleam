//// Product model - data operations only
////
//// This module handles database operations and returns domain types.
//// All presentation concerns are handled in the view layer.

import types/product.{type Product, Product}
import types/errors.{type DataError, NotFound, DatabaseError}
import sql
import dream_postgres/query
import dream_postgres/client
import gleam/list

/// Get a single product by ID
pub fn get(db: client.Connection, id: Int) -> Result(Product, DataError) {
  case sql.get_product(db, id) |> query.first_row() {
    Ok(row) -> Ok(row_to_product(row))
    Error(query.NotFound) -> Error(NotFound)
    Error(query.DatabaseError) -> Error(DatabaseError)
  }
}

/// List all products
pub fn list(db: client.Connection) -> Result(List(Product), DataError) {
  case sql.list_products(db) |> query.all_rows() {
    Ok(rows) -> Ok(list.map(rows, row_to_product_list))
    Error(_) -> Error(DatabaseError)
  }
}

// Private helpers - all named functions

fn row_to_product(row: sql.GetProductRow) -> Product {
  Product(id: row.id, name: row.name, price: row.price, stock: row.stock)
}

fn row_to_product_list(row: sql.ListProductsRow) -> Product {
  Product(id: row.id, name: row.name, price: row.price, stock: row.stock)
}
