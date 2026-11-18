//// Naming conventions: Lifecycle Management
////
//// `start_{noun}` and `stop_{noun}` run and halt a service. `init_{noun}`
//// prepares a resource, and `shutdown_{noun}` closes it cleanly.

import dream/http.{ok, text_response}
import dream/http/request.{Get}
import dream/router
import dream/servers/mist/server
import gleam/result

pub type DatabaseConfig {
  DatabaseConfig(url: String, pool_size: Int)
}

pub type Database {
  Database(url: String, connections: Int)
}

pub type Services {
  Services(database: Database)
}

pub fn start_server(port: Int) {
  server.new()
  |> server.router(app_router())
  |> server.listen_with_handle(port)
}

pub fn stop_server(handle: server.ServerHandle) -> Nil {
  server.stop(handle)
}

pub fn init_database(config: DatabaseConfig) -> Result(Database, String) {
  case config.pool_size > 0 {
    True -> Ok(Database(url: config.url, connections: config.pool_size))
    False -> Error("pool_size must be greater than 0")
  }
}

pub fn init_services(config: DatabaseConfig) -> Result(Services, String) {
  use database <- result.try(init_database(config))
  Ok(Services(database:))
}

pub fn shutdown_database(database: Database) -> Database {
  Database(..database, connections: 0)
}

pub fn shutdown_services(services: Services) -> Services {
  Services(database: shutdown_database(services.database))
}

fn app_router() {
  router.router()
  |> router.route(method: Get, path: "/", controller: index, middleware: [])
}

fn index(_request, _context, _services) {
  text_response(ok, "Home")
}
