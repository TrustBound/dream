//// A Dream app in a container
////
//// It reads its settings from the environment, answers `/health` with the
//// state of its database, and listens on all interfaces.
//// docs/guides/deployment.md builds it with the Dockerfile of this folder and
//// starts it, its database and its migrations with docker-compose.yml.

import dream/context.{type EmptyContext}
import dream/http.{
  type Request, type Response, ok, service_unavailable, text_response,
}
import dream/http/request.{Get}
import dream/router.{type Router, route, router}
import dream/servers/mist/server
import envoy
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/otp/actor
import gleam/result
import pog

pub type Services {
  Services(check_database: fn() -> Result(Nil, String))
}

pub fn main() -> Nil {
  case start() {
    Ok(Nil) -> Nil
    Error(reason) -> io.println_error("Cannot start the app: " <> reason)
  }
}

fn start() -> Result(Nil, String) {
  use database_url <- result.try(
    envoy.get("DATABASE_URL")
    |> result.replace_error("DATABASE_URL is not set"),
  )
  use port <- result.try(read_port())
  use connection <- result.try(connect(database_url))
  let services = Services(check_database: fn() { check_database(connection) })
  server.new()
  |> server.services(services)
  |> server.router(create_router())
  // Listen on all interfaces, so that the container's port reaches the app
  |> server.bind("0.0.0.0")
  |> server.listen(port)
  Ok(Nil)
}

// PORT is optional, but a PORT that is not a number is an error
fn read_port() -> Result(Int, String) {
  case envoy.get("PORT") {
    Error(Nil) -> Ok(3000)
    Ok(value) ->
      int.parse(value)
      |> result.replace_error("PORT must be a number, got: " <> value)
  }
}

fn connect(database_url: String) -> Result(pog.Connection, String) {
  let pool_name = process.new_name("app_database")
  use config <- result.try(
    pog.url_config(pool_name, database_url)
    |> result.replace_error("DATABASE_URL is not a PostgreSQL URL"),
  )
  case pog.start(config |> pog.pool_size(5)) {
    Ok(actor.Started(_pid, connection)) -> Ok(connection)
    Error(_start_error) -> Error("the PostgreSQL pool did not start")
  }
}

fn check_database(connection: pog.Connection) -> Result(Nil, String) {
  pog.query("SELECT 1")
  |> pog.execute(on: connection)
  |> result.replace(Nil)
  |> result.replace_error("Database unavailable")
}

fn index(
  _request: Request,
  _context: EmptyContext,
  _services: Services,
) -> Response {
  text_response(ok, "Hello from a container!")
}

fn health_check(
  _request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  case services.check_database() {
    Ok(Nil) -> text_response(ok, "OK")
    Error(_reason) -> text_response(service_unavailable, "Database unavailable")
  }
}

fn create_router() -> Router(EmptyContext, Services) {
  router()
  |> route(method: Get, path: "/", controller: index, middleware: [])
  |> route(
    method: Get,
    path: "/health",
    controller: health_check,
    middleware: [],
  )
}
