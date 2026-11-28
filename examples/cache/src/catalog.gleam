//// The product catalog. It stands in for a database: each read waits a set
//// time, as a query on a busy database can.

import dream_ets/config
import dream_ets/operations
import dream_ets/table.{type EtsError, type Table}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode.{type Decoder}
import gleam/erlang/process
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string

pub type Product {
  Product(id: String, name: String, price_in_cents: Int)
}

pub type CatalogError {
  /// No product has this id
  UnknownProduct(id: String)
  /// An ETS operation failed
  StoreFailed(reason: String)
}

pub opaque type Catalog {
  Catalog(products: Table(String, Product), delay_milliseconds: Int)
}

/// Makes the catalog table with `products` in it. The process that calls
/// this function owns the table.
pub fn new(
  name: String,
  delay_milliseconds: Int,
  products: List(Product),
) -> Result(Catalog, EtsError) {
  use table <- result.try(
    config.new(name)
    |> config.key_string()
    |> config.value(encode_product, product_decoder())
    |> config.read_concurrency(True)
    |> config.create(),
  )
  use Nil <- result.map(
    list.try_each(products, fn(product) {
      operations.set(table, product.id, product)
    }),
  )
  Catalog(products: table, delay_milliseconds:)
}

/// The product with `id`. Slow: it waits `delay_milliseconds` first.
pub fn find_product(
  catalog: Catalog,
  id: String,
) -> Result(Product, CatalogError) {
  process.sleep(catalog.delay_milliseconds)
  case operations.get(catalog.products, id) {
    Ok(Some(product)) -> Ok(product)
    Ok(None) -> Error(UnknownProduct(id:))
    Error(error) -> Error(store_failed(error))
  }
}

/// Gives the product with `id` a new price
pub fn change_price(
  catalog: Catalog,
  id: String,
  price_in_cents: Int,
) -> Result(Product, CatalogError) {
  use product <- result.try(find_product(catalog, id))
  let changed = Product(..product, price_in_cents:)
  operations.set(catalog.products, id, changed)
  |> result.map_error(store_failed)
  |> result.replace(changed)
}

/// The text of an ETS error, for a `StoreFailed`
pub fn store_failed(error: EtsError) -> CatalogError {
  StoreFailed(reason: string.inspect(error))
}

/// A product as an Erlang map, for an ETS row
pub fn encode_product(product: Product) -> Dynamic {
  dynamic.properties([
    #(dynamic.string("id"), dynamic.string(product.id)),
    #(dynamic.string("name"), dynamic.string(product.name)),
    #(dynamic.string("price_in_cents"), dynamic.int(product.price_in_cents)),
  ])
}

/// Reads a product from the map that `encode_product` makes
pub fn product_decoder() -> Decoder(Product) {
  use id <- decode.field("id", decode.string)
  use name <- decode.field("name", decode.string)
  use price_in_cents <- decode.field("price_in_cents", decode.int)
  decode.success(Product(id:, name:, price_in_cents:))
}
