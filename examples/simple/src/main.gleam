//// main.gleam

import dream/servers/mist/server.{bind, listen, router} as dream
import router.{create_router}

pub fn main() {
  dream.new()
  |> router(create_router())
  |> bind("localhost")
  |> listen(3000)
}
