//// Example for the doc of `error.GatewayTimeout`.

import dream/http/error.{type Error, GatewayTimeout}
import gleam/result

pub fn fetch_quote(
  upstream_result: Result(String, Nil),
) -> Result(String, Error) {
  upstream_result
  |> result.replace_error(GatewayTimeout("Quote service did not answer"))
}
