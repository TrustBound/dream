//// Product view - presentation logic for products
////
//// Pure formatting functions: Product → String
//// No Result types, no Response types, no error handling.

import gleam/float
import gleam/int
import gleam/json
import gleam/list
import gleam/yielder
import models/product.{type Product}
import views/products/templates/card
import views/products/templates/index as index_view
import views/products/templates/show as show_view

/// Format single product as JSON string
pub fn to_json(product: Product) -> String {
  to_json_object(product)
  |> json.to_string()
}

/// Format single product as HTML string
pub fn to_html(product: Product) -> String {
  show_view.render(product)
}

/// Format single product as HTMX partial string
pub fn to_htmx(product: Product) -> String {
  card.render(product)
}

/// Format single product as CSV row string
pub fn to_csv(product: Product) -> String {
  int.to_string(product.id)
  <> ","
  <> product.name
  <> ","
  <> float.to_string(product.price)
  <> ","
  <> int.to_string(product.stock)
}

/// Format list of products as JSON array string
pub fn list_to_json(products: List(Product)) -> String {
  list.map(products, to_json_object)
  |> json.array(from: _, of: identity)
  |> json.to_string()
}

/// Format list of products as HTML string
pub fn list_to_html(products: List(Product)) -> String {
  index_view.render(products)
}

/// Format list of products as CSV stream
pub fn list_to_csv_stream(
  products: List(Product),
) -> yielder.Yielder(BitArray) {
  let header = "id,name,price,stock\n"
  yielder.from_list([header, ..list.map(products, product_to_csv_row)])
  |> yielder.map(string_to_bit_array)
}

// Private helpers - all named functions

fn to_json_object(p: Product) -> json.Json {
  json.object([
    #("id", json.int(p.id)),
    #("name", json.string(p.name)),
    #("price", json.float(p.price)),
    #("stock", json.int(p.stock)),
  ])
}

fn product_to_csv_row(p: Product) -> String {
  int.to_string(p.id)
  <> ","
  <> p.name
  <> ","
  <> float.to_string(p.price)
  <> ","
  <> int.to_string(p.stock)
  <> "\n"
}

fn string_to_bit_array(s: String) -> BitArray {
  <<s:utf8>>
}

fn identity(x: a) -> a {
  x
}
