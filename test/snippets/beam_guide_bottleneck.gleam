//// BEAM guide: one process that every request calls, and an ETS table

import gleam/erlang/process.{type Subject}
import gleam/otp/actor
import snippets/beam_guide_cache.{type Table}

pub type PriceMessage {
  GetPrice(sku: String, reply: Subject(Result(Int, Nil)))
}

/// Wrong: one process looks up the price for every request
pub fn start_price_server(
  lookup_price: fn(String) -> Result(Int, Nil),
) -> actor.StartResult(Subject(PriceMessage)) {
  actor.new(Nil)
  |> actor.on_message(fn(state, message) {
    case message {
      GetPrice(sku, reply) -> {
        process.send(reply, lookup_price(sku))
        actor.continue(state)
      }
    }
  })
  |> actor.start
}

/// Each request calls the price server, and waits its turn
pub fn price(prices: Subject(PriceMessage), sku: String) -> Result(Int, Nil) {
  process.call(prices, waiting: 1000, sending: GetPrice(sku, _))
}

/// Fix: each request reads the table itself, so no request waits for
/// another one
pub fn price_from_table(table: Table, sku: String) -> Result(Int, Nil) {
  beam_guide_cache.lookup(table, sku)
}
