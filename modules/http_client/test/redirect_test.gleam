//// Auto-redirect integration tests
////
//// Tests the shim's manual redirect-following logic against live mock server
//// endpoints. Gun does not auto-redirect natively, so the shim implements
//// redirect following for 301, 302, 303, 307, and 308 status codes.

import dream_http_client/client
import dream_http_client_test
import gleam/bit_array
import gleam/bytes_tree
import gleam/erlang/process
import gleam/http
import gleam/list
import gleam/string
import gleam/yielder
import gleeunit/should

fn mock_request(path: String) -> client.ClientRequest {
  client.new()
  |> client.method(http.Get)
  |> client.scheme(http.Http)
  |> client.host("localhost")
  |> client.port(dream_http_client_test.get_test_port())
  |> client.path(path)
}

// ============================================================================
// send() redirect tests
// ============================================================================

pub fn send_follows_301_redirect_test() {
  let req = mock_request("/redirect/301")
  let assert Ok(resp) = client.send(req)
  resp.status |> should.equal(200)
  string.contains(resp.body, "Hello") |> should.be_true()
}

pub fn send_follows_302_redirect_test() {
  let req = mock_request("/redirect/302")
  let assert Ok(resp) = client.send(req)
  resp.status |> should.equal(200)
  string.contains(resp.body, "Hello") |> should.be_true()
}

pub fn send_follows_303_redirect_test() {
  let req = mock_request("/redirect/303")
  let assert Ok(resp) = client.send(req)
  resp.status |> should.equal(200)
  string.contains(resp.body, "Hello") |> should.be_true()
}

pub fn send_follows_307_redirect_test() {
  let req = mock_request("/redirect/307")
  let assert Ok(resp) = client.send(req)
  resp.status |> should.equal(200)
  string.contains(resp.body, "Hello") |> should.be_true()
}

pub fn send_follows_308_redirect_test() {
  let req = mock_request("/redirect/308")
  let assert Ok(resp) = client.send(req)
  resp.status |> should.equal(200)
  string.contains(resp.body, "Hello") |> should.be_true()
}

pub fn send_auto_redirect_false_returns_3xx_test() {
  let req =
    mock_request("/redirect/301")
    |> client.auto_redirect(False)
  let assert Ok(resp) = client.send(req)
  resp.status |> should.equal(301)
  let has_location =
    list.any(resp.headers, fn(h) { string.lowercase(h.name) == "location" })
  has_location |> should.be_true()
}

pub fn send_follows_redirect_chain_test() {
  let req = mock_request("/redirect/chain")
  let assert Ok(resp) = client.send(req)
  resp.status |> should.equal(200)
  string.contains(resp.body, "Hello") |> should.be_true()
}

pub fn send_follows_absolute_url_redirect_test() {
  let req = mock_request("/redirect/absolute")
  let assert Ok(resp) = client.send(req)
  resp.status |> should.equal(200)
  string.contains(resp.body, "Hello") |> should.be_true()
}

// ============================================================================
// stream_yielder() redirect tests
// ============================================================================

pub fn stream_yielder_follows_301_redirect_test() {
  let req = mock_request("/redirect/301")
  let results = client.stream_yielder(req) |> yielder.to_list

  { results != [] } |> should.be_true()

  let combined = combine_stream_chunks(results)
  string.contains(combined, "Hello") |> should.be_true()
}

pub fn stream_yielder_follows_redirect_chain_test() {
  let req = mock_request("/redirect/chain")
  let results = client.stream_yielder(req) |> yielder.to_list

  { results != [] } |> should.be_true()

  let combined = combine_stream_chunks(results)
  string.contains(combined, "Hello") |> should.be_true()
}

// ============================================================================
// start_stream() redirect tests
// ============================================================================

pub fn start_stream_follows_301_redirect_test() {
  let chunks_subject = process.new_subject()
  let ended_subject = process.new_subject()
  let error_subject = process.new_subject()

  let request =
    mock_request("/redirect/301")
    |> client.on_stream_chunk(fn(data) { process.send(chunks_subject, data) })
    |> client.on_stream_end(fn(_headers) { process.send(ended_subject, True) })
    |> client.on_stream_error(fn(reason) { process.send(error_subject, reason) })

  let assert Ok(_handle) = client.start_stream(request)

  case process.receive(ended_subject, 10_000) {
    Ok(True) -> {
      let chunks = collect_chunks(chunks_subject, [])
      { chunks != [] } |> should.be_true()
      let combined = combine_bit_chunks(chunks)
      string.contains(combined, "Hello") |> should.be_true()
    }
    Ok(False) -> should.fail()
    Error(Nil) -> {
      case process.receive(error_subject, 1000) {
        Ok(_reason) -> should.fail()
        Error(Nil) -> should.fail()
      }
    }
  }
}

// ============================================================================
// Helpers
// ============================================================================

fn collect_chunks(
  subject: process.Subject(BitArray),
  acc: List(BitArray),
) -> List(BitArray) {
  case process.receive(subject, 100) {
    Ok(item) -> collect_chunks(subject, [item, ..acc])
    Error(Nil) -> list.reverse(acc)
  }
}

fn combine_stream_chunks(
  results: List(Result(bytes_tree.BytesTree, String)),
) -> String {
  let chunks =
    list.filter_map(results, fn(r) {
      case r {
        Ok(bt) -> Ok(bytes_tree.to_bit_array(bt))
        Error(_) -> Error(Nil)
      }
    })
  combine_bit_chunks(chunks)
}

fn combine_bit_chunks(chunks: List(BitArray)) -> String {
  let combined =
    list.fold(chunks, <<>>, fn(acc, chunk) { bit_array.append(acc, chunk) })
  case bit_array.to_string(combined) {
    Ok(s) -> s
    Error(Nil) -> ""
  }
}
