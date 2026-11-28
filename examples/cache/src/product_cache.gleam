//// A read-through cache of products, with expiry. It keeps each product
//// that it reads from the catalog in an ETS table for a set time.

import catalog.{type Catalog, type CatalogError, type Product}
import dream_ets/config
import dream_ets/operations
import dream_ets/table.{type EtsError, type Table}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode.{type Decoder}
import gleam/option.{None, Some}
import gleam/order
import gleam/result
import gleam/time/duration.{type Duration}
import gleam/time/timestamp.{type Timestamp}

/// Where the product came from
pub type Lookup {
  /// From the cache: the catalog did not run
  Hit(product: Product)
  /// From the catalog: the cache now holds the product
  Miss(product: Product)
}

pub opaque type ProductCache {
  ProductCache(entries: Table(String, Entry), time_to_live: Duration)
}

type Entry {
  Entry(product: Product, expires_at: Timestamp)
}

/// Makes the cache table. The process that calls this function owns the
/// table. Each entry stays for `time_to_live`.
pub fn new(
  name: String,
  time_to_live: Duration,
) -> Result(ProductCache, EtsError) {
  config.new(name)
  |> config.key_string()
  |> config.value(encode_entry, entry_decoder())
  |> config.read_concurrency(True)
  |> config.create()
  |> result.map(fn(entries) { ProductCache(entries:, time_to_live:) })
}

/// The product with `id`: from the cache while its entry is fresh at `now`,
/// otherwise from the catalog, and then into the cache.
pub fn find_product(
  cache: ProductCache,
  catalog: Catalog,
  id: String,
  now: Timestamp,
) -> Result(Lookup, CatalogError) {
  case operations.get(cache.entries, id) {
    Ok(Some(entry)) -> use_entry(cache, catalog, id, entry, now)
    Ok(None) -> load_product(cache, catalog, id, now)
    Error(error) -> Error(catalog.store_failed(error))
  }
}

fn use_entry(
  cache: ProductCache,
  catalog: Catalog,
  id: String,
  entry: Entry,
  now: Timestamp,
) -> Result(Lookup, CatalogError) {
  case timestamp.compare(now, entry.expires_at) {
    order.Lt -> Ok(Hit(entry.product))
    order.Eq | order.Gt -> load_product(cache, catalog, id, now)
  }
}

fn load_product(
  cache: ProductCache,
  catalog: Catalog,
  id: String,
  now: Timestamp,
) -> Result(Lookup, CatalogError) {
  use product <- result.try(catalog.find_product(catalog, id))
  let entry =
    Entry(product:, expires_at: timestamp.add(now, cache.time_to_live))
  operations.set(cache.entries, id, entry)
  |> result.map_error(catalog.store_failed)
  |> result.replace(Miss(product))
}

/// Removes the entry of `id`, so that the next read gets the product from
/// the catalog. Call it after each write to the catalog.
pub fn forget_product(
  cache: ProductCache,
  id: String,
) -> Result(Nil, CatalogError) {
  operations.delete(cache.entries, id)
  |> result.map_error(catalog.store_failed)
}

fn encode_entry(entry: Entry) -> Dynamic {
  let #(seconds, nanoseconds) =
    timestamp.to_unix_seconds_and_nanoseconds(entry.expires_at)
  dynamic.properties([
    #(dynamic.string("product"), catalog.encode_product(entry.product)),
    #(dynamic.string("expires_at_seconds"), dynamic.int(seconds)),
    #(dynamic.string("expires_at_nanoseconds"), dynamic.int(nanoseconds)),
  ])
}

fn entry_decoder() -> Decoder(Entry) {
  use product <- decode.field("product", catalog.product_decoder())
  use seconds <- decode.field("expires_at_seconds", decode.int)
  use nanoseconds <- decode.field("expires_at_nanoseconds", decode.int)
  let expires_at =
    timestamp.from_unix_seconds_and_nanoseconds(seconds, nanoseconds)
  decode.success(Entry(product:, expires_at:))
}
