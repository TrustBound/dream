//// Page View Analytics
////
//// Example snippet showing a counter for page views.

import dream_ets/helpers
import dream_ets/table
import gleam/result

pub fn count_homepage_view() -> Result(Int, table.EtsError) {
  use counter <- result.try(helpers.new_counter("analytics"))
  use views <- result.try(helpers.increment(counter, "homepage"))
  Ok(views)
}
