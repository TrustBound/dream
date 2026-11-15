//// Naming conventions: Factory Function Exception
////
//// A factory function can be named after the type that it makes, when the
//// name and the module make it clear what it makes.

import dream/http.{ok, text_response}
import dream/http/request.{Get}
import dream/router
import gleam/string

pub type User {
  User(id: Int, name: String)
}

pub type Services {
  Services(users: List(User))
}

pub type Database {
  Database(url: String)
}

pub fn app_router() {
  // Router constructor: the router module creates a Router
  let app_router = router.router()
  app_router
  |> router.route(method: Get, path: "/", controller: index, middleware: [])
}

// Ambiguous: what does this initialize?
// Use create_services or init_services instead.
pub fn initialize() -> Result(Services, String) {
  Ok(Services(users: []))
}

// Ambiguous: which user? From where?
// Use create_user or load_user instead.
pub fn user() -> Result(User, String) {
  Ok(User(id: 1, name: "Ada"))
}

// Clearly creates a Database
pub fn database(url: String) -> Result(Database, String) {
  case string.starts_with(url, "postgres://") {
    True -> Ok(Database(url:))
    False -> Error("The database URL must start with postgres://")
  }
}

fn index(_request, _context, _services) {
  text_response(ok, "Home")
}
