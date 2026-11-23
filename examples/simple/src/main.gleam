//// main.gleam

import dream/servers/mist/server.{bind, listen, max_body_size, router} as dream
import router.{create_router}

pub fn main() {
  dream.new()
  |> router(create_router())
  |> bind("localhost")
  // Refuse a buffered request body over 1 MB
  |> max_body_size(1_000_000)
  |> listen(3000)
}
