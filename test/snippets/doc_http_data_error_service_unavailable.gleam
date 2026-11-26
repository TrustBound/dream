//// Example for the doc of `error.ServiceUnavailable`.

import dream/http/error.{type Error, ServiceUnavailable}
import gleam/result

pub fn load_rates(cache_result: Result(Float, Nil)) -> Result(Float, Error) {
  cache_result
  |> result.replace_error(ServiceUnavailable("Rate service is down"))
}
