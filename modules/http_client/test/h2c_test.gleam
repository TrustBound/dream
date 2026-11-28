//// h2c integration tests — HTTP/2 over cleartext (prior knowledge mode)
////
//// Verifies that dream_http_client with Http2Only over TCP successfully
//// negotiates HTTP/2 with a Mist-based server and correctly routes requests
//// to the right endpoints. Tests all three execution modes (send,
//// stream_yielder, start_stream) with path-specific content assertions.

import dream_http_client/client.{Header, Http1Only, Http2Only, Http2Preferred}
import dream_http_client_test
import gleam/bit_array
import gleam/bytes_tree
import gleam/erlang/process
import gleam/http
import gleam/list
import gleam/option
import gleam/string
import gleam/yielder
import gleeunit/should

fn h2c_request(path: String) -> client.ClientRequest {
  client.new()
  |> client.method(http.Get)
  |> client.scheme(http.Http)
  |> client.host("localhost")
  |> client.port(dream_http_client_test.get_test_port())
  |> client.path(path)
  |> client.protocols(Http2Only)
}

fn http1_request(path: String) -> client.ClientRequest {
  client.new()
  |> client.method(http.Get)
  |> client.scheme(http.Http)
  |> client.host("localhost")
  |> client.port(dream_http_client_test.get_test_port())
  |> client.path(path)
}

// ============================================================================
// A. send() over h2c — path-specific routing
// ============================================================================

/// h2c routes to /text and returns the correct body
pub fn h2c_send_text_returns_correct_body_test() {
  let req = h2c_request("/text")
  let assert Ok(resp) = client.send(req)
  resp.status |> should.equal(200)
  resp.body |> should.equal("Hello, World!")
}

/// h2c routes to /json and returns JSON with correct content
pub fn h2c_send_json_returns_correct_body_test() {
  let req = h2c_request("/json")
  let assert Ok(resp) = client.send(req)
  resp.status |> should.equal(200)
  string.contains(resp.body, "Hello, World!") |> should.be_true()
}

/// h2c routes to /status/500 and surfaces the error
pub fn h2c_send_error_status_test() {
  let req = h2c_request("/status/500")
  case client.send(req) {
    Error(client.ResponseError(response: client.HttpResponse(
      status: status,
      body: _body,
      ..,
    ))) -> {
      status |> should.equal(500)
    }
    Ok(resp) -> {
      let _ = resp
      should.fail()
    }
    _other -> {
      should.fail()
    }
  }
}

/// h2c POST with body routes correctly
pub fn h2c_send_post_with_body_test() {
  let req =
    h2c_request("/post")
    |> client.method(http.Post)
    |> client.body("{\"key\":\"value\"}")
    |> client.headers([Header("Content-Type", "application/json")])

  case client.send(req) {
    Ok(resp) -> {
      resp.status |> should.equal(201)
      string.contains(resp.body, "key") |> should.be_true()
    }
    Error(err) -> {
      let _ = err
      should.fail()
    }
  }
}

/// h2c decompresses gzip responses correctly
pub fn h2c_send_decompresses_gzip_test() {
  let req = h2c_request("/gzip")
  let assert Ok(resp) = client.send(req)
  resp.status |> should.equal(200)
  resp.body |> should.equal("Hello, World!")
}

/// h2c send() returns response headers
pub fn h2c_send_returns_headers_test() {
  let req = h2c_request("/text")
  let assert Ok(resp) = client.send(req)
  let content_type =
    list.find(resp.headers, fn(h) {
      let Header(name, _) = h
      string.lowercase(name) == "content-type"
    })
  let assert Ok(Header(_, ct_value)) = content_type
  string.contains(ct_value, "text/plain") |> should.be_true()
}

// ============================================================================
// B. stream_yielder() over h2c — path-specific routing
// ============================================================================

/// h2c stream_yielder to /stream/fast receives all 10 chunks
pub fn h2c_stream_yielder_receives_all_chunks_test() {
  let req = h2c_request("/stream/fast")
  let results = client.stream_yielder(req) |> yielder.to_list

  let ok_chunks =
    list.filter_map(results, fn(r) {
      case r {
        Ok(bt) -> Ok(bytes_tree.to_bit_array(bt))
        Error(_) -> Error(Nil)
      }
    })

  { ok_chunks != [] } |> should.be_true()

  let combined = combine_chunks(ok_chunks)
  string.contains(combined, "Chunk 1") |> should.be_true()
  string.contains(combined, "Chunk 10") |> should.be_true()
}

/// h2c stream_yielder decompresses gzip chunks
pub fn h2c_stream_yielder_decompresses_gzip_test() {
  let req = h2c_request("/stream/gzip")
  let results = client.stream_yielder(req) |> yielder.to_list

  let ok_chunks =
    list.filter_map(results, fn(r) {
      case r {
        Ok(bt) -> Ok(bytes_tree.to_bit_array(bt))
        Error(_) -> Error(Nil)
      }
    })

  { ok_chunks != [] } |> should.be_true()

  let combined = combine_chunks(ok_chunks)
  string.contains(combined, "Chunk 1") |> should.be_true()
  string.contains(combined, "Chunk 5") |> should.be_true()
}

// ============================================================================
// C. start_stream() over h2c — path-specific routing
// ============================================================================

/// h2c start_stream to /stream/fast delivers correct chunks
pub fn h2c_start_stream_delivers_correct_chunks_test() {
  let chunks_subject = process.new_subject()
  let ended_subject = process.new_subject()

  let request =
    h2c_request("/stream/fast")
    |> client.on_stream_chunk(fn(data) { process.send(chunks_subject, data) })
    |> client.on_stream_end(fn(_headers) { process.send(ended_subject, True) })
    |> client.on_stream_error(fn(_failure) {
      process.send(ended_subject, False)
    })

  let assert Ok(_handle) = client.start_stream(request)

  case process.receive(ended_subject, 10_000) {
    Ok(ended_ok) -> ended_ok |> should.be_true()
    Error(Nil) -> should.fail()
  }

  let chunks = collect_chunks(chunks_subject, [])
  { chunks != [] } |> should.be_true()
  let combined = combine_chunks(chunks)
  string.contains(combined, "Chunk 1") |> should.be_true()
}

/// h2c start_stream fires on_stream_start with headers
pub fn h2c_start_stream_fires_on_stream_start_test() {
  let headers_subject = process.new_subject()
  let ended_subject = process.new_subject()

  let request =
    h2c_request("/stream/fast")
    |> client.on_stream_start(fn(headers) {
      process.send(headers_subject, headers)
    })
    |> client.on_stream_chunk(fn(_data) { Nil })
    |> client.on_stream_end(fn(_headers) { process.send(ended_subject, True) })
    |> client.on_stream_error(fn(_failure) {
      process.send(ended_subject, False)
    })

  let assert Ok(_handle) = client.start_stream(request)

  case process.receive(headers_subject, 10_000) {
    Ok(headers) -> {
      { headers != [] } |> should.be_true()
    }
    Error(Nil) -> should.fail()
  }

  case process.receive(ended_subject, 10_000) {
    Ok(_) -> Nil
    Error(Nil) -> should.fail()
  }
}

// ============================================================================
// D. Connection pool isolation — h2c and http1 use separate connections
// ============================================================================

/// HTTP/1.1 requests still work after h2c requests
pub fn http1_still_works_after_h2c_test() {
  let _h2c = client.send(h2c_request("/text"))

  let assert Ok(resp) = client.send(http1_request("/text"))
  resp.status |> should.equal(200)
  resp.body |> should.equal("Hello, World!")
}

/// h2c returns correct content (not the index page)
pub fn h2c_returns_correct_content_not_index_page_test() {
  let assert Ok(h2c_resp) = client.send(h2c_request("/text"))
  h2c_resp.status |> should.equal(200)
  h2c_resp.body |> should.equal("Hello, World!")

  // Must NOT be the index page (which is what broken h2c returns)
  string.contains(h2c_resp.body, "Mock Server") |> should.be_false()
}

// ============================================================================
// C. Protocol builder API — verify protocols field round-trips
// ============================================================================

pub fn protocols_builder_sets_http2_only_test() {
  let req =
    client.new()
    |> client.protocols(Http2Only)
  client.get_protocols(req)
  |> should.equal(option.Some(Http2Only))
}

pub fn protocols_builder_sets_http1_only_test() {
  let req =
    client.new()
    |> client.protocols(Http1Only)
  client.get_protocols(req)
  |> should.equal(option.Some(Http1Only))
}

pub fn protocols_builder_sets_http2_preferred_test() {
  let req =
    client.new()
    |> client.protocols(Http2Preferred)
  client.get_protocols(req)
  |> should.equal(option.Some(Http2Preferred))
}

pub fn protocols_defaults_to_none_test() {
  let req = client.new()
  client.get_protocols(req)
  |> should.equal(option.None)
}

// ============================================================================
// D. Multiple concurrent h2c requests
// ============================================================================

pub fn concurrent_h2c_requests_all_succeed_test() {
  let subject1 = process.new_subject()
  let subject2 = process.new_subject()
  let subject3 = process.new_subject()

  let _pid1 =
    process.spawn_unlinked(fn() {
      let result = client.send(h2c_request("/text"))
      process.send(subject1, result)
    })

  let _pid2 =
    process.spawn_unlinked(fn() {
      let result = client.send(h2c_request("/text"))
      process.send(subject2, result)
    })

  let _pid3 =
    process.spawn_unlinked(fn() {
      let result = client.send(h2c_request("/text"))
      process.send(subject3, result)
    })

  let assert Ok(Ok(resp1)) = process.receive(subject1, 10_000)
  let assert Ok(Ok(resp2)) = process.receive(subject2, 10_000)
  let assert Ok(Ok(resp3)) = process.receive(subject3, 10_000)

  resp1.status |> should.equal(200)
  resp2.status |> should.equal(200)
  resp3.status |> should.equal(200)

  { string.length(resp1.body) > 0 } |> should.be_true()
  { string.length(resp2.body) > 0 } |> should.be_true()
  { string.length(resp3.body) > 0 } |> should.be_true()
}

// ============================================================================
// E. Http1Only explicitly forces HTTP/1.1
// ============================================================================

pub fn http1_only_returns_correct_content_test() {
  let req =
    client.new()
    |> client.method(http.Get)
    |> client.scheme(http.Http)
    |> client.host("localhost")
    |> client.port(dream_http_client_test.get_test_port())
    |> client.path("/text")
    |> client.protocols(Http1Only)

  let assert Ok(resp) = client.send(req)
  resp.status |> should.equal(200)
  resp.body |> should.equal("Hello, World!")
}

pub fn http1_only_stream_yielder_returns_correct_content_test() {
  let req =
    client.new()
    |> client.method(http.Get)
    |> client.scheme(http.Http)
    |> client.host("localhost")
    |> client.port(dream_http_client_test.get_test_port())
    |> client.path("/stream/fast")
    |> client.protocols(Http1Only)

  let results = client.stream_yielder(req) |> yielder.to_list

  let ok_chunks =
    list.filter_map(results, fn(r) {
      case r {
        Ok(bt) -> Ok(bytes_tree.to_bit_array(bt))
        Error(_) -> Error(Nil)
      }
    })

  { ok_chunks != [] } |> should.be_true()

  let combined = combine_chunks(ok_chunks)
  string.contains(combined, "Chunk 1") |> should.be_true()
  string.contains(combined, "Chunk 10") |> should.be_true()
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

fn combine_chunks(chunks: List(BitArray)) -> String {
  let combined =
    list.fold(chunks, <<>>, fn(acc, chunk) { bit_array.append(acc, chunk) })
  case bit_array.to_string(combined) {
    Ok(s) -> s
    Error(Nil) -> ""
  }
}
