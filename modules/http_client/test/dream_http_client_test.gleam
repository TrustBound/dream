import dream_http_client/client
import dream_mock_server/server
import gleam/erlang/process
import gleam/http
import gleam/int
import gleam/io
import gleam/result
import gleam/string
import gleeunit

pub fn get_test_port() -> Int {
  get_env("MOCK_SERVER_PORT", "9876")
  |> int.parse
  |> result.unwrap(9876)
}

@external(erlang, "env_ffi", "get_env")
fn get_env(name: String, default: String) -> String

pub fn main() {
  let port = get_test_port()

  case server.start(port) {
    Ok(_handle) -> {
      process.sleep(500)
      test_server_ready(port)
    }
    Error(start_error) -> {
      io.println("Mock server failed to start: " <> string.inspect(start_error))
    }
  }

  gleeunit.main()
}

fn test_server_ready(port: Int) -> Nil {
  let test_req =
    client.new
    |> client.method(http.Get)
    |> client.scheme(http.Http)
    |> client.host("localhost")
    |> client.port(port)
    |> client.path("/text")

  case client.send(test_req) {
    Ok(body) -> {
      case string.length(body) > 0 {
        True -> Nil
        False -> {
          io.println("Server returned empty response - aborting tests")
          exit_with_error()
        }
      }
    }
    Error(error_msg) -> {
      io.println("Server not responding: " <> error_msg)
      exit_with_error()
    }
  }
}

@external(erlang, "erlang", "halt")
fn exit_with_error() -> Nil
