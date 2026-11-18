//// Streaming guide: CSV Export Streaming
////
//// A controller that streams products as CSV rows, as shown in
//// docs/guides/streaming.md.

import dream/http/request.{type Request}
import dream/http/response.{type Response, stream_response, text_response}
import dream/http/status
import gleam/bit_array
import gleam/float
import gleam/int
import gleam/result
import gleam/yielder

pub type Product {
  Product(id: Int, name: String, price: Float, stock: Int)
}

pub type Services {
  Services(list_products: fn() -> Result(List(Product), String))
}

pub fn export_products(
  _request: Request,
  _context,
  services: Services,
) -> Response {
  services.list_products()
  |> result.map(products_to_csv_stream)
  |> result.map(create_csv_response)
  |> result.lazy_unwrap(create_error_response)
}

fn create_csv_response(stream: yielder.Yielder(BitArray)) -> Response {
  stream_response(status.ok, stream, "text/csv")
}

fn create_error_response() -> Response {
  text_response(status.internal_server_error, "Could not load products")
}

fn products_to_csv_stream(
  products: List(Product),
) -> yielder.Yielder(BitArray) {
  yielder.from_list(products)
  |> yielder.map(product_to_csv_row)
  |> yielder.prepend("id,name,price,stock\n")
  |> yielder.map(bit_array.from_string)
}

fn product_to_csv_row(product: Product) -> String {
  int.to_string(product.id)
  <> ","
  <> product.name
  <> ","
  <> float.to_string(product.price)
  <> ","
  <> int.to_string(product.stock)
  <> "\n"
}
