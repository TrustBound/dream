//// Examples for the `dream/context` module doc: a custom context type and a
//// server that uses it.

import dream/servers/mist/server.{context, listen, router, services}
import gleam/option.{None}

pub type MyContext {
  MyContext(
    request_id: String,
    user: option.Option(User),
    session: Session,
    permissions: List(String),
  )
}

pub fn start(my_services, my_router) {
  server.new()
  |> context(
    MyContext(
      request_id: "",
      user: None,
      session: empty_session(),
      permissions: [],
    ),
  )
  |> services(my_services)
  |> router(my_router)
  |> listen(3000)
}

pub type User {
  User(name: String)
}

pub type Session {
  Session(values: List(#(String, String)))
}

pub fn empty_session() -> Session {
  Session(values: [])
}
