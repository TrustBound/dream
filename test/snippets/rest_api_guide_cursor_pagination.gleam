//// REST API guide: cursor-based pagination
////
//// One page of products after an opaque cursor, as shown in
//// docs/guides/rest-api.md. A real app runs the same logic in SQL with
//// `WHERE id > $1 ORDER BY id LIMIT $2`.

import dream/http/error.{type Error, BadRequest}
import gleam/bit_array
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result

pub type Product {
  Product(id: Int, name: String)
}

pub type Page {
  Page(items: List(Product), next_cursor: Option(String))
}

// models/product.gleam
pub fn list_after(
  products: List(Product),
  cursor: Option(String),
  limit: Int,
) -> Result(Page, Error) {
  case decode_cursor(cursor) {
    Ok(after_id) -> Ok(page_after(products, after_id, limit))
    Error(_) -> Error(BadRequest("Invalid cursor"))
  }
}

fn page_after(products: List(Product), after_id: Int, limit: Int) -> Page {
  // Read one row more than the page holds, to know if a next page exists
  let rows =
    products
    |> list.drop_while(is_at_or_before(_, after_id))
    |> list.take(limit + 1)
  let items = list.take(rows, limit)
  case list.length(rows) > limit, list.last(items) {
    True, Ok(last) -> Page(items, Some(encode_cursor(last.id)))
    _, _ -> Page(items, None)
  }
}

fn is_at_or_before(product: Product, after_id: Int) -> Bool {
  product.id <= after_id
}

fn encode_cursor(id: Int) -> String {
  int.to_string(id)
  |> bit_array.from_string
  |> bit_array.base64_url_encode(False)
}

fn decode_cursor(cursor: Option(String)) -> Result(Int, Nil) {
  case cursor {
    // No cursor: start before the first id
    None -> Ok(0)
    Some(text) -> parse_cursor(text)
  }
}

fn parse_cursor(text: String) -> Result(Int, Nil) {
  use bits <- result.try(bit_array.base64_url_decode(text))
  use digits <- result.try(bit_array.to_string(bits))
  int.parse(digits)
}
