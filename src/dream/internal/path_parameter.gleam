//// The lookup of a path parameter, shared by `dream/http/request` and
//// `dream/http/transaction`, so a missing parameter gives one message.

import gleam/list
import gleam/result

/// The raw value of the path parameter `name`, or the message
/// `Missing required path parameter: <name>` when the route has no such
/// parameter.
pub fn find(
  params: List(#(String, String)),
  name: String,
) -> Result(String, String) {
  list.key_find(params, name)
  |> result.replace_error("Missing required path parameter: " <> name)
}
