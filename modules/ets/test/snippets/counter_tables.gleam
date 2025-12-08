//// Counter Tables
////
//// Example snippet showing how to increment a counter.

import dream_ets/helpers
import dream_ets/table
import gleam/result

pub fn increment_page_views() -> Result(Int, table.EtsError) {
  use counter <- result.try(helpers.new_counter("page_views"))

  // Track multiple page views
  use _ <- result.try(helpers.increment(counter, "homepage"))
  use _ <- result.try(helpers.increment(counter, "homepage"))
  use count <- result.try(helpers.increment(counter, "homepage"))

  Ok(count)
}
