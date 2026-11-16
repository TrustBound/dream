//// Tests for the order of the server builder calls.
////
//// `context()` and `services()` come before `router()`, and `listen()` needs a
//// router. The compiler enforces that order, so these tests show that the
//// right order builds and serves, and that the settings that do not depend on
//// the order (`bind`, `max_body_size`, `tls`) work before and after `router()`.

import dream/dream
import dream/http/request.{Get}
import dream/http/response.{text_response}
import dream/http/status
import dream/router.{type Router, route, router}
import dream/servers/mist/server
import dream_http_client/client
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}
import gleam/http
import gleam/option.{Some}
import gleam/result
import gleam/string
import mist.{type Connection, type ResponseData}

pub type OrderContext {
  OrderContext(name: String)
}

pub type OrderServices {
  OrderServices(greeting: String)
}

pub fn tests() -> UnitTest {
  describe("builder order", [
    right_order_tests(),
    settings_before_router_tests(),
    settings_after_router_tests(),
    settings_through_context_tests(),
  ])
}

fn right_order_tests() -> UnitTest {
  describe("context, services, router, then listen", [
    it("serves a request with a router that ignores the context", fn() {
      // Arrange
      let port = free_port()
      let app =
        server.new()
        |> server.context(OrderContext(name: "order"))
        |> server.services(OrderServices(greeting: "hello"))
        |> server.router(generic_router())

      // Act
      let result = serve_one_request(app, port)

      // Assert
      result
      |> should()
      |> equal(Ok(#(200, "Served in order")))
      |> or_fail_with("The app should serve the request on the given port")
    }),
    it("serves a request with a router typed by the context", fn() {
      // Arrange
      let port = free_port()
      let app =
        server.new()
        |> server.context(OrderContext(name: "typed"))
        |> server.services(OrderServices(greeting: "hello"))
        |> server.router(typed_router())

      // Act
      let result = serve_one_request(app, port)

      // Assert
      result
      |> should()
      |> equal(Ok(#(200, "typed: hello")))
      |> or_fail_with("The controller should get the context and services")
    }),
    it("get_router returns the router given to router()", fn() {
      // Arrange
      let the_router = generic_router()

      // Act
      let app =
        server.new()
        |> server.context(OrderContext(name: "order"))
        |> server.router(the_router)

      // Assert
      dream.get_router(app)
      |> should()
      |> equal(the_router)
      |> or_fail_with("The app should hold the router it was given")
    }),
    it("get_services returns the services given to services()", fn() {
      // Arrange
      let app =
        server.new()
        |> server.services(OrderServices(greeting: "hello"))
        |> server.router(generic_router())

      // Act
      let services = dream.get_services(app)

      // Assert
      services
      |> should()
      |> equal(OrderServices(greeting: "hello"))
      |> or_fail_with("The app should hold the services it was given")
    }),
    it("get_router returns NoRouter before router()", fn() {
      // Arrange
      let app = server.new()

      // Act
      let router_state = dream.get_router(app)

      // Assert
      router_state
      |> should()
      |> equal(dream.NoRouter)
      |> or_fail_with("A new app should have no router")
    }),
  ])
}

fn settings_before_router_tests() -> UnitTest {
  describe("settings before router()", [
    it("bind before router() keeps the interface", fn() {
      // Arrange
      let app =
        server.new()
        |> server.bind("127.0.0.1")

      // Act
      let configured = server.router(app, generic_router())

      // Assert
      dream.get_bind_interface(configured)
      |> should()
      |> equal(Some("127.0.0.1"))
      |> or_fail_with("router() should keep the bind interface")
    }),
    it("max_body_size before router() keeps the size", fn() {
      // Arrange
      let app =
        server.new()
        |> server.max_body_size(2048)

      // Act
      let configured = server.router(app, generic_router())

      // Assert
      dream.get_max_body_size(configured)
      |> should()
      |> equal(2048)
      |> or_fail_with("router() should keep the max body size")
    }),
    it("tls before router() keeps the certificate and key", fn() {
      // Arrange
      let app =
        server.new()
        |> server.tls(certfile: "cert.pem", keyfile: "key.pem")

      // Act
      let configured = server.router(app, generic_router())

      // Assert
      dream.get_tls(configured)
      |> should()
      |> equal(Some(dream.Tls(certfile: "cert.pem", keyfile: "key.pem")))
      |> or_fail_with("router() should keep the TLS files")
    }),
  ])
}

fn settings_after_router_tests() -> UnitTest {
  describe("settings after router()", [
    it("bind after router() sets the interface", fn() {
      // Arrange
      let app =
        server.new()
        |> server.router(generic_router())

      // Act
      let configured = server.bind(app, "127.0.0.1")

      // Assert
      dream.get_bind_interface(configured)
      |> should()
      |> equal(Some("127.0.0.1"))
      |> or_fail_with("bind() should set the interface after router()")
    }),
    it("bind after router() keeps the router", fn() {
      // Arrange
      let the_router = generic_router()
      let app =
        server.new()
        |> server.router(the_router)

      // Act
      let configured = server.bind(app, "127.0.0.1")

      // Assert
      dream.get_router(configured)
      |> should()
      |> equal(the_router)
      |> or_fail_with("bind() should keep the router")
    }),
    it("max_body_size after router() sets the size", fn() {
      // Arrange
      let app =
        server.new()
        |> server.router(generic_router())

      // Act
      let configured = server.max_body_size(app, 2048)

      // Assert
      dream.get_max_body_size(configured)
      |> should()
      |> equal(2048)
      |> or_fail_with("max_body_size() should set the size after router()")
    }),
    it("tls after router() sets the certificate and key", fn() {
      // Arrange
      let app =
        server.new()
        |> server.router(generic_router())

      // Act
      let configured = server.tls(app, certfile: "cert.pem", keyfile: "key.pem")

      // Assert
      dream.get_tls(configured)
      |> should()
      |> equal(Some(dream.Tls(certfile: "cert.pem", keyfile: "key.pem")))
      |> or_fail_with("tls() should set the TLS files after router()")
    }),
    it("a server with bind and max_body_size after router() serves", fn() {
      // Arrange
      let port = free_port()
      let app =
        server.new()
        |> server.context(OrderContext(name: "order"))
        |> server.router(generic_router())
        |> server.bind("127.0.0.1")
        |> server.max_body_size(2048)

      // Act
      let result = serve_one_request(app, port)

      // Assert
      result
      |> should()
      |> equal(Ok(#(200, "Served in order")))
      |> or_fail_with("The app should serve with settings after router()")
    }),
  ])
}

fn settings_through_context_tests() -> UnitTest {
  describe("settings through context() and services()", [
    it("context() keeps the bind interface set before it", fn() {
      // Arrange
      let app =
        server.new()
        |> server.bind("127.0.0.1")

      // Act
      let configured = server.context(app, OrderContext(name: "order"))

      // Assert
      dream.get_bind_interface(configured)
      |> should()
      |> equal(Some("127.0.0.1"))
      |> or_fail_with("context() should keep the bind interface")
    }),
    it("services() keeps the max body size set before it", fn() {
      // Arrange
      let app =
        server.new()
        |> server.max_body_size(2048)

      // Act
      let configured = server.services(app, OrderServices(greeting: "hello"))

      // Assert
      dream.get_max_body_size(configured)
      |> should()
      |> equal(2048)
      |> or_fail_with("services() should keep the max body size")
    }),
    it("context() keeps the TLS files set before it", fn() {
      // Arrange
      let app =
        server.new()
        |> server.tls(certfile: "cert.pem", keyfile: "key.pem")

      // Act
      let configured = server.context(app, OrderContext(name: "order"))

      // Assert
      dream.get_tls(configured)
      |> should()
      |> equal(Some(dream.Tls(certfile: "cert.pem", keyfile: "key.pem")))
      |> or_fail_with("context() should keep the TLS files")
    }),
  ])
}

// ============================================================================
// Helpers
// ============================================================================

fn order_controller(_request, _context, _services) {
  text_response(status.ok, "Served in order")
}

fn typed_controller(_request, context: OrderContext, services: OrderServices) {
  text_response(status.ok, context.name <> ": " <> services.greeting)
}

/// A router whose controller ignores the context and services types, so its
/// type is generic.
fn generic_router() -> Router(context, services) {
  router()
  |> route(method: Get, path: "/", controller: order_controller, middleware: [])
}

fn typed_router() -> Router(OrderContext, OrderServices) {
  router()
  |> route(method: Get, path: "/", controller: typed_controller, middleware: [])
}

/// Starts the app on `port`, sends `GET /`, stops the app, and returns the
/// status and body of the response.
fn serve_one_request(
  app: dream.Dream(
    mist.Builder(Connection, ResponseData),
    context,
    services,
    Router(context, services),
  ),
  port: Int,
) -> Result(#(Int, String), String) {
  use handle <- result.try(
    server.listen_with_handle(app, port)
    |> result.map_error(fn(start_error) {
      "Server failed to start: " <> string.inspect(start_error)
    }),
  )
  let response = get_root(port)
  server.stop(handle)
  response
}

fn get_root(port: Int) -> Result(#(Int, String), String) {
  client.new()
  |> client.method(http.Get)
  |> client.scheme(http.Http)
  |> client.host("localhost")
  |> client.port(port)
  |> client.path("/")
  |> client.send()
  |> result.map(fn(response) { #(response.status, response.body) })
  |> result.map_error(fn(send_error) {
    "Request failed: " <> string.inspect(send_error)
  })
}

@external(erlang, "doc_server_ffi", "free_port")
fn free_port() -> Int
