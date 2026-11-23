//// Tests for dream/servers/mist/handler module.
////
//// The handler takes a mist request. The tests that call it build one with
//// a test connection from fixtures/mist_connection, so they need no server.
//// The integration tests cover the end-to-end behavior with a real server.

import dream/context.{type AppContext}
import dream/http/request.{
  type BodyReadError, type Request, Get, MalformedBody, Other, Post, Stream,
}
import dream/http/response.{type Response, Response, text_response}
import dream/router.{type EmptyServices, route, router, stream_route}
import dream/servers/mist/handler
import dream/servers/mist/sse
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/types.{AssertionOk}
import dream_test/unit.{describe, group, it}
import fixtures/mist_connection
import gleam/erlang/process.{type Selector, type Subject}
import gleam/http
import gleam/option.{type Option, None}
import gleam/result
import gleam/yielder

const max_body_size = 10

pub fn tests() -> TestSuite {
  describe("handler", [
    group("create", [
      it("returns a handler function with valid config", fn() {
        let test_router = router.router()
        let max_body_size = 1024
        let template_context = context.AppContext(request_id: "")
        let services_instance = router.EmptyServices
        let update_context_function = fn(
          app_context: AppContext,
          _request_id: String,
        ) -> AppContext {
          app_context
        }

        // Handler function should be callable (it's a function)
        // We verify it's not Nil or causing a panic just by creating it
        let _ =
          handler.create(
            test_router,
            max_body_size,
            template_context,
            services_instance,
            update_context_function,
          )

        Ok(AssertionOk)
      }),
    ]),
    group("request body errors", [
      it("answers 400 when a buffered body is larger than the limit", fn() {
        // Arrange
        let connection = mist_connection.closed_connection(<<>>)
        let request =
          mist_connection.request(connection, http.Post, "/buffered", [
            #("content-length", "100"),
          ])

        // Act
        let response = test_handler()(request)

        // Assert
        response.status
        |> should()
        |> be_equal(400)
        |> or_fail_with("A body over max_body_size should get 400")
      }),
      it("answers 400 when a streamed body cannot be read", fn() {
        // Arrange
        let connection = mist_connection.closed_connection(<<>>)
        let request =
          mist_connection.request(connection, http.Post, "/streaming", [
            #("content-length", "5"),
            #("expect", "100-continue"),
          ])

        // Act
        let response = test_handler()(request)

        // Assert
        response.status
        |> should()
        |> be_equal(400)
        |> or_fail_with(
          "A stream_route body that cannot be read should get 400",
        )
      }),
      it(
        "gives the controller one Error item when a streamed body breaks",
        fn() {
          // Arrange
          let storage = process.new_subject()
          let request = broken_upload_request()

          // Act
          let _response = storing_handler(storage)(request)
          let stored = process.receive(storage, 0)

          // Assert
          stored
          |> should()
          |> be_equal(Ok([Error(MalformedBody)]))
          |> or_fail_with("The stream should give one Error item, then end")
        },
      ),
      it(
        "answers with the controller response when a streamed body breaks",
        fn() {
          // Arrange
          let storage = process.new_subject()
          let request = broken_upload_request()

          // Act
          let response = storing_handler(storage)(request)

          // Assert
          response.status
          |> should()
          |> be_equal(422)
          |> or_fail_with("The controller owns the answer to a broken body")
        },
      ),
    ]),
    group("methods", [
      it("answers PURGE / with 404 when only GET / has a route", fn() {
        // Arrange
        let connection = mist_connection.closed_connection(<<>>)
        let request =
          mist_connection.request(connection, http.Other("PURGE"), "/", [])

        // Act
        let response = method_handler()(request)

        // Assert
        response.status
        |> should()
        |> be_equal(404)
        |> or_fail_with("PURGE / should not run the GET controller")
      }),
      it("answers TRACE / with 404 when only GET / has a route", fn() {
        // Arrange
        let connection = mist_connection.closed_connection(<<>>)
        let request = mist_connection.request(connection, http.Trace, "/", [])

        // Act
        let response = method_handler()(request)

        // Assert
        response.status
        |> should()
        |> be_equal(404)
        |> or_fail_with("TRACE / should not run the GET controller")
      }),
      it("runs the PURGE route for PURGE /cache", fn() {
        // Arrange
        let connection = mist_connection.closed_connection(<<>>)
        let request =
          mist_connection.request(connection, http.Other("PURGE"), "/cache", [])

        // Act
        let response = method_handler()(request)

        // Assert
        response.status
        |> should()
        |> be_equal(202)
        |> or_fail_with("PURGE /cache should run the PURGE controller")
      }),
    ]),
    group("deferred SSE upgrade", [
      it("sends the normal response when the status is not 200", fn() {
        // Arrange
        let connection = mist_connection.closed_connection(<<>>)
        let request =
          mist_connection.request(connection, http.Get, "/events", [])

        // Act
        let response = test_handler()(request)

        // Assert
        response.status
        |> should()
        |> be_equal(403)
        |> or_fail_with("A 403 from middleware should stop the SSE upgrade")
      }),
    ]),
  ])
}

// ============================================================================
// Handler, router and controllers
// ============================================================================

fn test_handler() {
  handler.create(
    test_router(),
    max_body_size,
    context.AppContext(request_id: ""),
    router.EmptyServices,
    keep_context,
  )
}

/// A handler with `GET /` and `PURGE /cache`. The PURGE controller answers
/// 202, so a test can tell it from the GET controller.
fn method_handler() {
  handler.create(
    router()
      |> route(
        method: Get,
        path: "/",
        controller: ok_controller,
        middleware: [],
      )
      |> route(
        method: Other("PURGE"),
        path: "/cache",
        controller: purge_controller,
        middleware: [],
      ),
    max_body_size,
    context.AppContext(request_id: ""),
    router.EmptyServices,
    keep_context,
  )
}

fn purge_controller(_request: Request, _context, _services) -> Response {
  text_response(202, "purged")
}

/// A streamed upload that declares 10 bytes. The client sent 5 bytes and the
/// connection is closed, so the read of the rest fails.
fn broken_upload_request() {
  let connection = mist_connection.closed_connection(<<"hello">>)
  mist_connection.request(connection, http.Post, "/upload", [
    #("content-length", "10"),
  ])
}

/// A handler whose upload controller reads every item of the stream, sends
/// the items to `storage`, and answers 422 when an item is an `Error`.
fn storing_handler(storage: Subject(List(Result(BitArray, BodyReadError)))) {
  handler.create(
    router()
      |> stream_route(
        method: Post,
        path: "/upload",
        controller: store_upload,
        middleware: [],
      ),
    max_body_size,
    context.AppContext(request_id: ""),
    storage,
    keep_context,
  )
}

fn store_upload(
  request: Request,
  _context: AppContext,
  storage: Subject(List(Result(BitArray, BodyReadError))),
) -> Response {
  case request.body {
    Stream(chunks) -> store_items(yielder.to_list(chunks), storage)
    _ -> text_response(500, "expected a stream")
  }
}

fn store_items(
  items: List(Result(BitArray, BodyReadError)),
  storage: Subject(List(Result(BitArray, BodyReadError))),
) -> Response {
  process.send(storage, items)
  case result.all(items) {
    Ok(_chunks) -> text_response(200, "stored")
    Error(_read_error) -> text_response(422, "the upload broke")
  }
}

fn keep_context(app_context: AppContext, _request_id: String) -> AppContext {
  app_context
}

fn test_router() -> router.Router(AppContext, EmptyServices) {
  router()
  |> route(
    method: Post,
    path: "/buffered",
    controller: ok_controller,
    middleware: [],
  )
  |> stream_route(
    method: Post,
    path: "/streaming",
    controller: ok_controller,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/events",
    controller: events_controller,
    middleware: [forbid_middleware],
  )
}

fn ok_controller(_request: Request, _context, _services) -> Response {
  text_response(200, "ok")
}

fn events_controller(request: Request, _context, _services) -> Response {
  sse.upgrade_to_sse(
    request,
    dependencies: Nil,
    on_init: init_events,
    on_message: handle_event,
  )
}

fn init_events(
  _subject: Subject(Nil),
  _dependencies: Nil,
) -> #(Nil, Option(Selector(Nil))) {
  #(Nil, None)
}

fn handle_event(
  _state: Nil,
  _message: Nil,
  _connection: sse.SSEConnection,
  _dependencies: Nil,
) -> sse.Action(Nil, Nil) {
  sse.stop_connection()
}

/// Runs the controller, then turns its answer into a 403.
fn forbid_middleware(
  request: Request,
  app_context: AppContext,
  services: EmptyServices,
  next: fn(Request, AppContext, EmptyServices) -> Response,
) -> Response {
  let response = next(request, app_context, services)
  Response(..response, status: 403)
}
