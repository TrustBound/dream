//// REST API guide: input validation
////
//// A decoder for product data, and a check that runs on the decoded value,
//// as shown in docs/guides/rest-api.md.

import gleam/dynamic/decode.{type Decoder, field, int, string, success}
import gleam/string.{is_empty}

pub type ProductData {
  ProductData(name: String, price: Int, description: String)
}

pub fn decoder() -> Decoder(ProductData) {
  use name <- field("name", string)
  use price <- field("price", int)
  use description <- field("description", string)
  success(ProductData(name, price, description))
}

// Validate after decoding
pub fn validate_product_data(data: ProductData) -> Result(ProductData, String) {
  case is_empty(data.name) {
    True -> Error("Name cannot be empty")
    False -> check_price(data)
  }
}

fn check_price(data: ProductData) -> Result(ProductData, String) {
  case data.price < 0 {
    True -> Error("Price cannot be negative")
    False -> Ok(data)
  }
}
