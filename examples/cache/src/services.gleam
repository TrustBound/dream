//// The services of the shop: the catalog, the product cache and the clock.
//// One process owns the two ETS tables and lives as long as the app.

import catalog.{type Catalog, Product}
import clock.{type Clock}
import gleam/erlang/process.{type Subject}
import gleam/result
import gleam/string
import gleam/time/duration.{type Duration}
import product_cache.{type ProductCache}

pub type Services {
  Services(
    catalog: Catalog,
    cache: ProductCache,
    clock: Clock,
    /// Send `Nil` here to stop the process that owns the tables
    table_owner: Subject(Nil),
  )
}

pub type Settings {
  Settings(
    /// The start of the name of each table
    table_prefix: String,
    /// How long each read of the catalog waits
    catalog_delay_milliseconds: Int,
    /// How long the cache keeps a product
    time_to_live: Duration,
    clock: Clock,
  )
}

/// Starts the process that owns the tables, and gives the services that
/// hold them.
pub fn start_services(settings: Settings) -> Result(Services, String) {
  let reply = process.new_subject()
  process.spawn(fn() { own_tables(settings, reply) })
  process.receive(reply, within: 5000)
  |> result.replace_error("The table owner did not start in 5 seconds")
  |> result.flatten
}

/// Stops the process that owns the tables. The tables go away with it.
pub fn stop_services(services: Services) -> Nil {
  process.send(services.table_owner, Nil)
}

/// Runs in the owner process: makes the tables, sends the services back,
/// and waits for the stop message. The tables live while this process
/// lives.
fn own_tables(settings: Settings, reply: Subject(Result(Services, String))) {
  let stop = process.new_subject()
  let started = create_services(settings, stop)
  process.send(reply, started)
  case result.is_ok(started) {
    True -> process.receive_forever(stop)
    False -> Nil
  }
}

fn create_services(
  settings: Settings,
  stop: Subject(Nil),
) -> Result(Services, String) {
  use catalog <- result.try(
    catalog.new(
      settings.table_prefix <> "_catalog",
      settings.catalog_delay_milliseconds,
      starting_products(),
    )
    |> result.map_error(string.inspect),
  )
  use cache <- result.map(
    product_cache.new(settings.table_prefix <> "_cache", settings.time_to_live)
    |> result.map_error(string.inspect),
  )
  Services(catalog:, cache:, clock: settings.clock, table_owner: stop)
}

fn starting_products() {
  [
    Product(id: "lamp", name: "Desk lamp", price_in_cents: 4500),
    Product(id: "mug", name: "Coffee mug", price_in_cents: 1200),
    Product(id: "chair", name: "Office chair", price_in_cents: 18_900),
  ]
}
