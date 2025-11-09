//// Product view - presentation logic for products
////
//// This module handles all presentation concerns including format conversion
//// (JSON, HTML, HTMX, CSV) and response generation.

import dream_helpers/statuses.{ok_status}
import dream/core/http/transaction.{type PathParam, type Response}
import dream_helpers/http.{
  html_response, json_response, stream_response, text_response,
}
import sql
import views/products/templates/card
import views/products/templates/index as index_view
import views/products/templates/show as show_view
import gleam/float
import gleam/int
import gleam/json
import gleam/list
import gleam/option
import gleam/yielder

/// Convert product to JSON string
pub fn to_json(product: sql.GetProductRow) -> String {
  json.object([
    #("id", json.int(product.id)),
    #("name", json.string(product.name)),
    #("price", json.float(product.price)),
    #("stock", json.int(product.stock)),
  ])
  |> json.to_string()
}

/// Convert product to full HTML page using Matcha template
pub fn to_html(product: sql.GetProductRow) -> String {
  show_view.render(product: product)
}

/// Convert product to HTMX partial using Matcha template
pub fn to_htmx(product: sql.GetProductRow) -> String {
  card.render(product: product)
}

/// Convert product to CSV row
pub fn to_csv(product: sql.GetProductRow) -> String {
  int.to_string(product.id)
  <> ","
  <> product.name
  <> ","
  <> float.to_string(product.price)
  <> ","
  <> int.to_string(product.stock)
}

/// Convert product list to JSON array string
pub fn list_to_json(products: List(sql.ListProductsRow)) -> String {
  products
  |> list.map(fn(p) {
    json.object([
      #("id", json.int(p.id)),
      #("name", json.string(p.name)),
      #("price", json.float(p.price)),
      #("stock", json.int(p.stock)),
    ])
  })
  |> json.array(from: _, of: fn(x) { x })
  |> json.to_string()
}

/// Convert product list to HTML using Matcha template
pub fn list_to_html(products: List(sql.ListProductsRow)) -> String {
  index_view.render(products: products)
}

/// Convert product list to CSV stream (demonstrates streaming)
pub fn list_to_csv_stream(
  products: List(sql.ListProductsRow),
) -> yielder.Yielder(BitArray) {
  let header = "id,name,price,stock\n"

  yielder.from_list([
    header,
    ..list.map(products, fn(p) {
      int.to_string(p.id)
      <> ","
      <> p.name
      <> ","
      <> float.to_string(p.price)
      <> ","
      <> int.to_string(p.stock)
      <> "\n"
    })
  ])
  |> yielder.map(fn(s) { <<s:utf8>> })
}

/// Respond with a single product in the appropriate format based on PathParam
pub fn respond(product: sql.GetProductRow, param: PathParam) -> Response {
  case param.format {
    option.Some("json") -> json_response(ok_status(), to_json(product))
    option.Some("htmx") -> html_response(ok_status(), to_htmx(product))
    option.Some("csv") -> text_response(ok_status(), to_csv(product))
    _ -> html_response(ok_status(), to_html(product))
  }
}

/// Respond with a product list in the appropriate format
pub fn respond_list(
  products: List(sql.ListProductsRow),
  format_param: option.Option(PathParam),
) -> Response {
  case format_param {
    option.Some(param) -> respond_list_with_format(products, param)
    option.None -> html_response(ok_status(), list_to_html(products))
  }
}

fn respond_list_with_format(
  products: List(sql.ListProductsRow),
  param: PathParam,
) -> Response {
  case param.format {
    option.Some("json") -> json_response(ok_status(), list_to_json(products))
    option.Some("csv") ->
      stream_response(ok_status(), list_to_csv_stream(products), "text/csv")
    _ -> html_response(ok_status(), list_to_html(products))
  }
}
