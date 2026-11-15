//// Lets Dream's Elixir integration tests send requests with
//// dream_http_client.
////
//// The Cucumber step definitions call `request/6` from Elixir as
//// `:integration_bridge.request(...)`. The same scenarios then run over
//// HTTP/1.1 and over HTTP/2, through Dream's own client.

import dream_http_client/client.{Http1Only, Http2Only}
import gleam/erlang/atom
import gleam/erlang/process.{type Pid}
import gleam/http
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import gleam/uri

/// Sends one request and waits for the whole response.
///
/// - `method`: an HTTP method, such as `"GET"`
/// - `url`: the full URL, such as `"https://localhost:3000/users/1"`
/// - `protocol`: `"http1"` or `"http2"`. With `"http2"` the client speaks only
///   HTTP/2, so a response proves the server answered over HTTP/2.
/// - `certificate_authority_file`: the PEM file to trust over HTTPS, or `""`
///   for the system certificate authorities
///
/// Returns `Ok(#(status, headers, body))`, or `Error(reason)` as text.
pub fn request(
  method: String,
  url: String,
  headers: List(#(String, String)),
  body: String,
  protocol: String,
  certificate_authority_file: String,
) -> Result(#(Int, List(#(String, String)), String), String) {
  use method <- result.try(
    http.parse_method(method)
    |> result.replace_error("Unknown HTTP method: " <> method),
  )
  use parsed <- result.try(
    uri.parse(url)
    |> result.replace_error("Invalid URL: " <> url),
  )
  use scheme <- result.try(parse_scheme(parsed.scheme))
  use protocols <- result.try(parse_protocol(protocol))

  let request =
    client.new()
    |> client.method(method)
    |> client.scheme(scheme)
    |> client.host(option.unwrap(parsed.host, "localhost"))
    |> client.path(parsed.path)
    |> client.body(body)
    |> client.protocols(protocols)
    |> client.auto_redirect(False)
    |> add_port(parsed.port)
    |> add_query(parsed.query)
    |> add_certificate_authority_file(certificate_authority_file)
    |> add_headers(headers)

  // The client returns responses with a status of 400 or more as
  // `ResponseError`. The scenarios check those statuses, so they count as
  // answers here.
  case client.send(request) {
    Ok(response) -> Ok(to_tuple(response))
    Error(client.ResponseError(response)) -> Ok(to_tuple(response))
    Error(error) -> Error(string.inspect(error))
  }
}

/// Starts a streaming request and sends what arrives to `receiver` as
/// messages, each tagged with `reference`:
///
/// - `{dream_stream_status, Reference, Status}` when the response starts
/// - `{dream_stream_headers, Reference, Headers}` right after it
/// - `{dream_stream_chunk, Reference, Data}` for each part of the body
/// - `{dream_stream_end, Reference}` at the end
/// - `{dream_stream_error, Reference, Reason}` on failure
///
/// The arguments are the same as for `request/6`, without a body.
pub fn stream(
  method: String,
  url: String,
  headers: List(#(String, String)),
  protocol: String,
  certificate_authority_file: String,
  receiver: Pid,
  reference: reference,
) -> Result(Nil, String) {
  use method <- result.try(
    http.parse_method(method)
    |> result.replace_error("Unknown HTTP method: " <> method),
  )
  use parsed <- result.try(
    uri.parse(url)
    |> result.replace_error("Invalid URL: " <> url),
  )
  use scheme <- result.try(parse_scheme(parsed.scheme))
  use protocols <- result.try(parse_protocol(protocol))

  client.new()
  |> client.method(method)
  |> client.scheme(scheme)
  |> client.host(option.unwrap(parsed.host, "localhost"))
  |> client.path(parsed.path)
  |> client.protocols(protocols)
  |> add_port(parsed.port)
  |> add_query(parsed.query)
  |> add_certificate_authority_file(certificate_authority_file)
  |> add_headers(headers)
  |> client.on_stream_start(fn(response_headers) {
    send(receiver, #(atom.create("dream_stream_status"), reference, 200))
    send(receiver, #(
      atom.create("dream_stream_headers"),
      reference,
      list.map(response_headers, fn(header) { #(header.name, header.value) }),
    ))
    Nil
  })
  |> client.on_stream_chunk(fn(data) {
    send(receiver, #(atom.create("dream_stream_chunk"), reference, data))
    Nil
  })
  |> client.on_stream_end(fn(_trailers) {
    send(receiver, #(atom.create("dream_stream_end"), reference))
    Nil
  })
  |> client.on_stream_error(fn(failure) {
    send(receiver, #(
      atom.create("dream_stream_error"),
      reference,
      string.inspect(failure),
    ))
    Nil
  })
  |> client.start_stream()
  |> result.replace(Nil)
}

@external(erlang, "erlang", "send")
fn send(receiver: Pid, message: message) -> message

fn to_tuple(
  response: client.HttpResponse,
) -> #(Int, List(#(String, String)), String) {
  #(
    response.status,
    list.map(response.headers, fn(header) { #(header.name, header.value) }),
    response.body,
  )
}

fn parse_scheme(scheme: option.Option(String)) -> Result(http.Scheme, String) {
  case scheme {
    Some("https") -> Ok(http.Https)
    Some("http") -> Ok(http.Http)
    Some(other) -> Error("Unsupported scheme: " <> other)
    None -> Error("The URL has no scheme")
  }
}

fn parse_protocol(protocol: String) -> Result(client.Protocols, String) {
  case protocol {
    "http1" -> Ok(Http1Only)
    "http2" -> Ok(Http2Only)
    other -> Error("Unknown protocol: " <> other <> " (use http1 or http2)")
  }
}

fn add_port(
  request: client.ClientRequest,
  port: option.Option(Int),
) -> client.ClientRequest {
  case port {
    Some(port) -> client.port(request, port)
    None -> request
  }
}

fn add_query(
  request: client.ClientRequest,
  query: option.Option(String),
) -> client.ClientRequest {
  case query {
    Some(query) -> client.query(request, query)
    None -> request
  }
}

fn add_certificate_authority_file(
  request: client.ClientRequest,
  path: String,
) -> client.ClientRequest {
  case path {
    "" -> request
    path -> client.certificate_authority_file(request, path)
  }
}

fn add_headers(
  request: client.ClientRequest,
  headers: List(#(String, String)),
) -> client.ClientRequest {
  list.fold(headers, request, fn(request, header) {
    client.add_header(request, header.0, header.1)
  })
}
