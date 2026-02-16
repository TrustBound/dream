//// Comprehensive tests for mock server config mode (start_with_config).
//// Covers path matching (exact, prefix, first-match order), method filtering,
//// status/body, no-match 404, empty config, and lifecycle.

import dream/http/request.{Get, Post}
import dream_mock_server/config.{Exact, MockRoute, Prefix}
import dream_mock_server/server
import gleam/bit_array
import gleam/erlang/process
import gleam/int
import gleam/option
import gleam/result
import gleeunit/should

// Port range for config-mode tests (avoid clashing with server_test 19876+)
fn config_test_port(base: Int) -> Int {
  19_890 + base
}

@external(erlang, "http_test_ffi", "make_request_full")
fn make_request_full(url: String) -> Result(#(Int, BitArray), BitArray)

@external(erlang, "http_test_ffi", "make_request_with_method")
fn make_request_with_method(
  url: String,
  method: String,
  body: String,
) -> Result(#(Int, BitArray), BitArray)

fn bits_to_string(bits: BitArray) -> String {
  bit_array.to_string(bits) |> result.unwrap("")
}

fn get(url: String) -> Result(#(Int, String), String) {
  case make_request_full(url) {
    Ok(#(status, body_bits)) -> Ok(#(status, bits_to_string(body_bits)))
    Error(err_bits) -> Error(bits_to_string(err_bits))
  }
}

fn post(url: String, body: String) -> Result(#(Int, String), String) {
  case make_request_with_method(url, "POST", body) {
    Ok(#(status, body_bits)) -> Ok(#(status, bits_to_string(body_bits)))
    Error(err_bits) -> Error(bits_to_string(err_bits))
  }
}

fn url(port: Int, path: String) -> String {
  "http://localhost:" <> int.to_string(port) <> path
}

// ----- Path matching -----

pub fn exact_match_returns_configured_response_test() {
  let port = config_test_port(0)
  let config = [
    MockRoute("/foo", Exact, option.None, 200, "exact-foo"),
  ]
  let assert Ok(handle) = server.start_with_config(port, config)
  process.sleep(200)

  let r = get(url(port, "/foo"))
  server.stop(handle)
  process.sleep(500)

  case r {
    Ok(#(status, body)) -> {
      should.equal(status, 200)
      should.equal(body, "exact-foo")
    }
    Error(_e) -> should.fail()
  }
}

pub fn exact_match_subpath_returns_404_test() {
  let port = config_test_port(1)
  let config = [
    MockRoute("/foo", Exact, option.None, 200, "ok"),
  ]
  let assert Ok(handle) = server.start_with_config(port, config)
  process.sleep(200)

  let r = get(url(port, "/foo/bar"))
  server.stop(handle)
  process.sleep(500)

  case r {
    Ok(#(status, body)) -> {
      should.equal(status, 404)
      should.equal(body, "Not found")
    }
    Error(_e) -> should.fail()
  }
}

pub fn prefix_match_returns_configured_response_test() {
  let port = config_test_port(2)
  let config = [
    MockRoute("/api", Prefix, option.None, 200, "api"),
  ]
  let assert Ok(handle) = server.start_with_config(port, config)
  process.sleep(200)

  let r1 = get(url(port, "/api"))
  let r2 = get(url(port, "/api/v1"))
  let r3 = get(url(port, "/api/v1/chat"))
  server.stop(handle)
  process.sleep(500)

  case r1 {
    Ok(#(s, b)) -> {
      should.equal(s, 200)
      should.equal(b, "api")
    }
    Error(_e) -> should.fail()
  }
  case r2 {
    Ok(#(s, b)) -> {
      should.equal(s, 200)
      should.equal(b, "api")
    }
    Error(_e) -> should.fail()
  }
  case r3 {
    Ok(#(s, b)) -> {
      should.equal(s, 200)
      should.equal(b, "api")
    }
    Error(_e) -> should.fail()
  }
}

pub fn prefix_no_match_returns_404_test() {
  let port = config_test_port(3)
  let config = [
    MockRoute("/api", Prefix, option.None, 200, "api"),
  ]
  let assert Ok(handle) = server.start_with_config(port, config)
  process.sleep(200)

  let r1 = get(url(port, "/ap"))
  let r2 = get(url(port, "/other"))
  server.stop(handle)
  process.sleep(500)

  case r1 {
    Ok(#(s, b)) -> {
      should.equal(s, 404)
      should.equal(b, "Not found")
    }
    Error(_e) -> should.fail()
  }
  case r2 {
    Ok(#(s, b)) -> {
      should.equal(s, 404)
      should.equal(b, "Not found")
    }
    Error(_e) -> should.fail()
  }
}

pub fn first_match_wins_order_test() {
  let port = config_test_port(4)
  // More specific first: /api/special exact, then /api prefix.
  let config = [
    MockRoute("/api/special", Exact, option.None, 200, "special"),
    MockRoute("/api", Prefix, option.None, 200, "api"),
  ]
  let assert Ok(handle) = server.start_with_config(port, config)
  process.sleep(200)

  let r_special = get(url(port, "/api/special"))
  let r_api = get(url(port, "/api"))
  let r_api_other = get(url(port, "/api/other"))
  server.stop(handle)
  process.sleep(500)

  case r_special {
    Ok(#(s, b)) -> {
      should.equal(s, 200)
      should.equal(b, "special")
    }
    Error(_e) -> should.fail()
  }
  case r_api {
    Ok(#(s, b)) -> {
      should.equal(s, 200)
      should.equal(b, "api")
    }
    Error(_e) -> should.fail()
  }
  case r_api_other {
    Ok(#(s, b)) -> {
      should.equal(s, 200)
      should.equal(b, "api")
    }
    Error(_e) -> should.fail()
  }
}

// ----- Method filtering -----

pub fn optional_method_any_method_matches_test() {
  let port = config_test_port(5)
  let config = [
    MockRoute("/any", Exact, option.None, 200, "ok"),
  ]
  let assert Ok(handle) = server.start_with_config(port, config)
  process.sleep(200)

  let r_get = get(url(port, "/any"))
  let r_post = post(url(port, "/any"), "")
  server.stop(handle)
  process.sleep(500)

  case r_get {
    Ok(#(s, b)) -> {
      should.equal(s, 200)
      should.equal(b, "ok")
    }
    Error(_e) -> should.fail()
  }
  case r_post {
    Ok(#(s, b)) -> {
      should.equal(s, 200)
      should.equal(b, "ok")
    }
    Error(_e) -> should.fail()
  }
}

pub fn specific_method_only_post_matches_test() {
  let port = config_test_port(6)
  let config = [
    MockRoute("/post-only", Exact, option.Some(Post), 201, "created"),
  ]
  let assert Ok(handle) = server.start_with_config(port, config)
  process.sleep(200)

  let r_post = post(url(port, "/post-only"), "")
  let r_get = get(url(port, "/post-only"))
  server.stop(handle)
  process.sleep(500)

  case r_post {
    Ok(#(s, b)) -> {
      should.equal(s, 201)
      should.equal(b, "created")
    }
    Error(_e) -> should.fail()
  }
  case r_get {
    Ok(#(s, b)) -> {
      should.equal(s, 404)
      should.equal(b, "Not found")
    }
    Error(_e) -> should.fail()
  }
}

pub fn multiple_methods_same_path_test() {
  let port = config_test_port(7)
  let config = [
    MockRoute("/r", Exact, option.Some(Get), 200, "get"),
    MockRoute("/r", Exact, option.Some(Post), 201, "post"),
  ]
  let assert Ok(handle) = server.start_with_config(port, config)
  process.sleep(200)

  let r_get = get(url(port, "/r"))
  let r_post = post(url(port, "/r"), "")
  server.stop(handle)
  process.sleep(500)

  case r_get {
    Ok(#(s, b)) -> {
      should.equal(s, 200)
      should.equal(b, "get")
    }
    Error(_e) -> should.fail()
  }
  case r_post {
    Ok(#(s, b)) -> {
      should.equal(s, 201)
      should.equal(b, "post")
    }
    Error(_e) -> should.fail()
  }
}

// ----- Status and body -----

pub fn non_200_status_returned_test() {
  let port = config_test_port(8)
  let config = [
    MockRoute("/created", Exact, option.None, 201, "created"),
    MockRoute("/error", Exact, option.None, 500, "server error"),
  ]
  let assert Ok(handle) = server.start_with_config(port, config)
  process.sleep(200)

  let r1 = get(url(port, "/created"))
  let r2 = get(url(port, "/error"))
  server.stop(handle)
  process.sleep(500)

  case r1 {
    Ok(#(s, b)) -> {
      should.equal(s, 201)
      should.equal(b, "created")
    }
    Error(_e) -> should.fail()
  }
  case r2 {
    Ok(#(s, b)) -> {
      should.equal(s, 500)
      should.equal(b, "server error")
    }
    Error(_e) -> should.fail()
  }
}

pub fn empty_body_returned_test() {
  let port = config_test_port(9)
  let config = [
    MockRoute("/empty", Exact, option.None, 200, ""),
  ]
  let assert Ok(handle) = server.start_with_config(port, config)
  process.sleep(200)

  let r = get(url(port, "/empty"))
  server.stop(handle)
  process.sleep(500)

  case r {
    Ok(#(status, body)) -> {
      should.equal(status, 200)
      should.equal(body, "")
    }
    Error(_e) -> should.fail()
  }
}

pub fn json_body_returned_verbatim_test() {
  let port = config_test_port(10)
  let body = "{\"key\":\"value\"}"
  let config = [
    MockRoute("/json", Exact, option.None, 200, body),
  ]
  let assert Ok(handle) = server.start_with_config(port, config)
  process.sleep(200)

  let r = get(url(port, "/json"))
  server.stop(handle)
  process.sleep(500)

  case r {
    Ok(#(status, res_body)) -> {
      should.equal(status, 200)
      should.equal(res_body, body)
    }
    Error(_e) -> should.fail()
  }
}

// ----- No match and edge cases -----

pub fn no_matching_path_returns_404_test() {
  let port = config_test_port(11)
  let config = [
    MockRoute("/a", Exact, option.None, 200, "a"),
    MockRoute("/b", Exact, option.None, 200, "b"),
  ]
  let assert Ok(handle) = server.start_with_config(port, config)
  process.sleep(200)

  let r1 = get(url(port, "/c"))
  let r2 = get(url(port, "/"))
  server.stop(handle)
  process.sleep(500)

  case r1 {
    Ok(#(s, b)) -> {
      should.equal(s, 404)
      should.equal(b, "Not found")
    }
    Error(_e) -> should.fail()
  }
  case r2 {
    Ok(#(s, b)) -> {
      should.equal(s, 404)
      should.equal(b, "Not found")
    }
    Error(_e) -> should.fail()
  }
}

pub fn path_matches_method_does_not_returns_404_test() {
  let port = config_test_port(12)
  let config = [
    MockRoute("/r", Exact, option.Some(Post), 200, "post"),
  ]
  let assert Ok(handle) = server.start_with_config(port, config)
  process.sleep(200)

  let r = get(url(port, "/r"))
  server.stop(handle)
  process.sleep(500)

  case r {
    Ok(#(s, b)) -> {
      should.equal(s, 404)
      should.equal(b, "Not found")
    }
    Error(_e) -> should.fail()
  }
}

pub fn empty_config_every_request_404_test() {
  let port = config_test_port(13)
  let config = []
  let assert Ok(handle) = server.start_with_config(port, config)
  process.sleep(200)

  let r = get(url(port, "/anything"))
  server.stop(handle)
  process.sleep(500)

  case r {
    Ok(#(s, b)) -> {
      should.equal(s, 404)
      should.equal(b, "Not found")
    }
    Error(_e) -> should.fail()
  }
}

// ----- Lifecycle -----

pub fn start_then_stop_then_restart_same_port_test() {
  let port = config_test_port(14)
  let config = [MockRoute("/x", Exact, option.None, 200, "x")]

  let assert Ok(handle1) = server.start_with_config(port, config)
  process.sleep(200)
  server.stop(handle1)
  process.sleep(500)

  let result2 = server.start_with_config(port, config)
  case result2 {
    Ok(handle2) -> {
      process.sleep(200)
      let r = get(url(port, "/x"))
      server.stop(handle2)
      process.sleep(500)
      case r {
        Ok(#(s, b)) -> {
          should.equal(s, 200)
          should.equal(b, "x")
        }
        Error(_e) -> should.fail()
      }
    }
    Error(_) -> Nil
  }
  should.be_ok(result2)
}
