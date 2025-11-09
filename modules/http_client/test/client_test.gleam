import dream_http_client/client
import gleam/http
import gleam/list
import gleam/option
import gleeunit/should

pub fn method_sets_request_method_test() {
  // Arrange
  let request = client.new

  // Act
  let updated = client.method(request, http.Post)

  // Assert
  case updated {
    client.ClientRequest(method, _, _, _, _, _, _, _) -> {
      case method {
        http.Post -> Nil
        _ -> should.fail()
      }
    }
  }
}

pub fn scheme_sets_request_scheme_test() {
  // Arrange
  let request = client.new

  // Act
  let updated = client.scheme(request, http.Http)

  // Assert
  case updated {
    client.ClientRequest(_, scheme, _, _, _, _, _, _) -> {
      case scheme {
        http.Http -> Nil
        _ -> should.fail()
      }
    }
  }
}

pub fn host_sets_request_host_test() {
  // Arrange
  let request = client.new
  let host_value = "example.com"

  // Act
  let updated = client.host(request, host_value)

  // Assert
  case updated {
    client.ClientRequest(_, _, host, _, _, _, _, _) -> {
      host |> should.equal(host_value)
    }
  }
}

pub fn port_sets_request_port_test() {
  // Arrange
  let request = client.new
  let port_value = 8080

  // Act
  let updated = client.port(request, port_value)

  // Assert
  case updated {
    client.ClientRequest(_, _, _, port, _, _, _, _) -> {
      case port {
        option.Some(p) -> p |> should.equal(port_value)
        option.None -> should.fail()
      }
    }
  }
}

pub fn path_sets_request_path_test() {
  // Arrange
  let request = client.new
  let path_value = "/api/users"

  // Act
  let updated = client.path(request, path_value)

  // Assert
  case updated {
    client.ClientRequest(_, _, _, _, path, _, _, _) -> {
      path |> should.equal(path_value)
    }
  }
}

pub fn query_sets_request_query_test() {
  // Arrange
  let request = client.new
  let query_value = "name=value"

  // Act
  let updated = client.query(request, query_value)

  // Assert
  case updated {
    client.ClientRequest(_, _, _, _, _, query, _, _) -> {
      case query {
        option.Some(q) -> q |> should.equal(query_value)
        option.None -> should.fail()
      }
    }
  }
}

pub fn headers_sets_request_headers_test() {
  // Arrange
  let request = client.new
  let headers_value = [#("Authorization", "Bearer token")]

  // Act
  let updated = client.headers(request, headers_value)

  // Assert
  case updated {
    client.ClientRequest(_, _, _, _, _, _, headers, _) -> {
      list.length(headers) |> should.equal(1)
    }
  }
}

pub fn body_sets_request_body_test() {
  // Arrange
  let request = client.new
  let body_value = "{\"key\":\"value\"}"

  // Act
  let updated = client.body(request, body_value)

  // Assert
  case updated {
    client.ClientRequest(_, _, _, _, _, _, _, body) -> {
      body |> should.equal(body_value)
    }
  }
}

pub fn add_header_adds_header_to_request_test() {
  // Arrange
  let request = client.new

  // Act
  let updated = client.add_header(request, "X-Custom", "value")

  // Assert
  case updated {
    client.ClientRequest(_, _, _, _, _, _, headers, _) -> {
      list.length(headers) |> should.equal(1)
      case headers {
        [#(name, value), ..] -> {
          name |> should.equal("X-Custom")
          value |> should.equal("value")
        }
        [] -> should.fail()
      }
    }
  }
}
