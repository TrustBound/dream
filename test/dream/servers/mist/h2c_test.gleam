//// Tests for HTTP/2 over cleartext (h2c) through dream's full server stack.
////
//// Starts a real dream server with routes, makes h2c requests via
//// dream_http_client with Http2Only, and asserts correct responses through
//// the complete pipeline: router dispatch, controller execution, response
//// conversion, and mist HTTP/2 frame handling.

import dream/http/request.{type Request, Get, Post}
import dream/http/response.{type Response, json_response, text_response}
import dream/router.{route, router}
import dream/servers/mist/server
import dream_http_client/client.{Http2Only, ResponseError}
import dream_test/types.{
  type AssertionResult, AssertionFailed, AssertionFailure, AssertionOk,
}
import dream_test/unit.{type UnitTest, describe, it}
import gleam/erlang/process
import gleam/http
import gleam/list
import gleam/option.{None}
import gleam/string

// ============================================================================
// Tests
// ============================================================================

pub fn tests() -> UnitTest {
  describe("h2c", [
    it("GET returns correct body over h2c", fn() {
      use handle <- with_h2c_server(19_980)

      let result =
        h2c_request("/h2c/hello", 19_980)
        |> client.send()

      server.stop(handle)

      case result {
        Ok(resp) -> {
          case resp.status == 200 && resp.body == "hello from dream over h2c" {
            True -> AssertionOk
            False ->
              assertion_failed(
                "h2c_get",
                "Expected status 200 and body 'hello from dream over h2c', got status "
                  <> string.inspect(resp.status)
                  <> " body '"
                  <> resp.body
                  <> "'",
              )
          }
        }
        Error(err) ->
          assertion_failed("h2c_get", "Request failed: " <> string.inspect(err))
      }
    }),
    it("path params work over h2c", fn() {
      use handle <- with_h2c_server(19_981)

      let result =
        h2c_request("/h2c/echo/test-value", 19_981)
        |> client.send()

      server.stop(handle)

      case result {
        Ok(resp) -> {
          case resp.status == 200 && string.contains(resp.body, "test-value") {
            True -> AssertionOk
            False ->
              assertion_failed(
                "h2c_path_params",
                "Expected status 200 with body containing 'test-value', got status "
                  <> string.inspect(resp.status)
                  <> " body '"
                  <> resp.body
                  <> "'",
              )
          }
        }
        Error(err) ->
          assertion_failed(
            "h2c_path_params",
            "Request failed: " <> string.inspect(err),
          )
      }
    }),
    it("JSON response has correct content-type over h2c", fn() {
      use handle <- with_h2c_server(19_982)

      let result =
        h2c_request("/h2c/json", 19_982)
        |> client.send()

      server.stop(handle)

      case result {
        Ok(resp) -> {
          let has_json_body = string.contains(resp.body, "\"greeting\"")
          let has_json_ct =
            list.any(resp.headers, fn(h) {
              let client.Header(name, value) = h
              string.lowercase(name) == "content-type"
              && string.contains(value, "application/json")
            })

          case resp.status == 200 && has_json_body && has_json_ct {
            True -> AssertionOk
            False ->
              assertion_failed(
                "h2c_json",
                "Expected status 200, JSON body with 'greeting', and application/json content-type. Got status "
                  <> string.inspect(resp.status)
                  <> " body '"
                  <> resp.body
                  <> "' headers "
                  <> string.inspect(resp.headers),
              )
          }
        }
        Error(err) ->
          assertion_failed(
            "h2c_json",
            "Request failed: " <> string.inspect(err),
          )
      }
    }),
    it("404 for unknown route over h2c", fn() {
      use handle <- with_h2c_server(19_983)

      let result =
        h2c_request("/h2c/nonexistent", 19_983)
        |> client.send()

      server.stop(handle)

      case result {
        Error(ResponseError(response: client.HttpResponse(status: 404, ..))) ->
          AssertionOk
        Error(ResponseError(response: client.HttpResponse(status: status, ..))) ->
          assertion_failed(
            "h2c_404",
            "Expected status 404, got " <> string.inspect(status),
          )
        Ok(resp) ->
          assertion_failed(
            "h2c_404",
            "Expected error response, got Ok with status "
              <> string.inspect(resp.status),
          )
        Error(err) ->
          assertion_failed(
            "h2c_404",
            "Unexpected error: " <> string.inspect(err),
          )
      }
    }),
    it("POST with body echoes back over h2c", fn() {
      use handle <- with_h2c_server(19_984)

      let payload = "h2c-test-payload"
      let result =
        h2c_request("/h2c/echo-body", 19_984)
        |> client.method(http.Post)
        |> client.body(payload)
        |> client.send()

      server.stop(handle)

      case result {
        Ok(resp) -> {
          case resp.status == 200 && string.contains(resp.body, payload) {
            True -> AssertionOk
            False ->
              assertion_failed(
                "h2c_post_body",
                "Expected status 200 with body containing '"
                  <> payload
                  <> "', got status "
                  <> string.inspect(resp.status)
                  <> " body '"
                  <> resp.body
                  <> "'",
              )
          }
        }
        Error(err) ->
          assertion_failed(
            "h2c_post_body",
            "Request failed: " <> string.inspect(err),
          )
      }
    }),
    it("concurrent requests succeed over h2c", fn() {
      use handle <- with_h2c_server(19_985)

      let subject1 = process.new_subject()
      let subject2 = process.new_subject()
      let subject3 = process.new_subject()

      let _pid1 =
        process.spawn_unlinked(fn() {
          let result =
            h2c_request("/h2c/hello", 19_985)
            |> client.send()
          process.send(subject1, result)
        })

      let _pid2 =
        process.spawn_unlinked(fn() {
          let result =
            h2c_request("/h2c/hello", 19_985)
            |> client.send()
          process.send(subject2, result)
        })

      let _pid3 =
        process.spawn_unlinked(fn() {
          let result =
            h2c_request("/h2c/hello", 19_985)
            |> client.send()
          process.send(subject3, result)
        })

      let r1 = process.receive(subject1, 10_000)
      let r2 = process.receive(subject2, 10_000)
      let r3 = process.receive(subject3, 10_000)

      server.stop(handle)

      case r1, r2, r3 {
        Ok(Ok(resp1)), Ok(Ok(resp2)), Ok(Ok(resp3)) -> {
          case
            resp1.status == 200
            && resp2.status == 200
            && resp3.status == 200
            && resp1.body == "hello from dream over h2c"
            && resp2.body == "hello from dream over h2c"
            && resp3.body == "hello from dream over h2c"
          {
            True -> AssertionOk
            False ->
              assertion_failed(
                "h2c_concurrent",
                "Not all responses matched. Got: "
                  <> string.inspect(#(resp1.status, resp2.status, resp3.status)),
              )
          }
        }
        _, _, _ ->
          assertion_failed(
            "h2c_concurrent",
            "One or more concurrent requests failed: "
              <> string.inspect(#(r1, r2, r3)),
          )
      }
    }),
  ])
}

// ============================================================================
// Helpers
// ============================================================================

fn h2c_request(path: String, port: Int) -> client.ClientRequest {
  client.new()
  |> client.method(http.Get)
  |> client.scheme(http.Http)
  |> client.host("localhost")
  |> client.port(port)
  |> client.path(path)
  |> client.protocols(Http2Only)
}

fn h2c_router() {
  router()
  |> route(
    method: Get,
    path: "/h2c/hello",
    controller: hello_controller,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/h2c/echo/:value",
    controller: echo_controller,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/h2c/json",
    controller: json_controller,
    middleware: [],
  )
  |> route(
    method: Post,
    path: "/h2c/echo-body",
    controller: echo_body_controller,
    middleware: [],
  )
}

fn hello_controller(_request: Request, _context, _services) -> Response {
  text_response(200, "hello from dream over h2c")
}

fn echo_controller(request: Request, _context, _services) -> Response {
  case request.get_param(request, "value") {
    Ok(param) -> text_response(200, param.value)
    Error(msg) -> text_response(400, msg)
  }
}

fn json_controller(_request: Request, _context, _services) -> Response {
  json_response(200, "{\"greeting\":\"hello from dream over h2c\"}")
}

fn echo_body_controller(request: Request, _context, _services) -> Response {
  text_response(200, request.body)
}

fn with_h2c_server(
  port: Int,
  test_fn: fn(server.ServerHandle) -> AssertionResult,
) -> AssertionResult {
  let result =
    server.new()
    |> server.router(h2c_router())
    |> server.listen_with_handle(port)

  case result {
    Ok(handle) -> {
      process.sleep(100)
      test_fn(handle)
    }
    Error(start_error) ->
      assertion_failed(
        "with_h2c_server",
        "Failed to start server on port "
          <> string.inspect(port)
          <> ": "
          <> string.inspect(start_error),
      )
  }
}

fn assertion_failed(operator: String, message: String) -> AssertionResult {
  AssertionFailed(AssertionFailure(
    operator: operator,
    message: message,
    payload: None,
  ))
}
