//// Doc comment example: dream/servers/mist/server.services

import dream/http.{ok, text_response}
import dream/http/request.{Get}
import dream/router.{type Router, route, router}
import dream/servers/mist/server

pub type Services {
  Services(database: Connection, cache: Cache)
}

pub fn initialize_services() -> Services {
  let database = connect_to_database()
  let cache = create_cache()
  Services(database: database, cache: cache)
}

pub fn main() {
  let assert Ok(Nil) =
    server.new()
    |> server.services(initialize_services())
    |> server.router(my_router())
    |> server.listen(3000)
}

pub type Connection {
  Connection(url: String)
}

pub type Cache {
  Cache(entries: List(#(String, String)))
}

fn connect_to_database() -> Connection {
  Connection(url: "postgres://localhost/app")
}

fn create_cache() -> Cache {
  Cache(entries: [])
}

pub fn my_router() -> Router(context, Services) {
  router()
  |> route(method: Get, path: "/", controller: index, middleware: [])
}

fn index(_request, _context, services: Services) {
  text_response(ok, services.database.url)
}
