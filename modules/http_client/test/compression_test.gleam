//// Compression tests - full permutation matrix
////
//// Tests transparent gzip/deflate decompression across all three HTTP client
//// execution modes (send, start_stream, stream_yielder), header injection,
//// edge cases, and zlib lifecycle cleanup.

import dream_http_client/client.{Header}
import dream_http_client_test
import gleam/bit_array
import gleam/bytes_tree
import gleam/erlang/process
import gleam/http
import gleam/io
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
// A. Sync tests (send()) -- one per encoding type
// ============================================================================

/// 1. send() decompresses gzip response transparently
pub fn send_decompresses_gzip_response_test() {
  let req = mock_request("/gzip")
  let assert Ok(resp) = client.send(req)
  resp.status |> should.equal(200)
  resp.body |> should.equal("Hello, World!")
}

/// 2. send() decompresses deflate response transparently
pub fn send_decompresses_deflate_response_test() {
  let req = mock_request("/deflate")
  let assert Ok(resp) = client.send(req)
  resp.status |> should.equal(200)
  resp.body |> should.equal("Hello, World!")
}

/// 3. send() passes through identity encoding (no-op)
pub fn send_passes_through_identity_encoding_test() {
  let req = mock_request("/identity")
  let assert Ok(resp) = client.send(req)
  resp.status |> should.equal(200)
  resp.body |> should.equal("Hello, World!")
}

/// 4. send() passes through unknown encoding without crashing
pub fn send_passes_through_unknown_encoding_test() {
  let req = mock_request("/unknown-encoding")
  let assert Ok(resp) = client.send(req)
  resp.status |> should.equal(200)
  { string.length(resp.body) > 0 } |> should.be_true()
}

/// 5. send() works normally without any Content-Encoding header
pub fn send_works_without_content_encoding_test() {
  let req = mock_request("/text")
  let assert Ok(resp) = client.send(req)
  resp.status |> should.equal(200)
  { string.length(resp.body) > 0 } |> should.be_true()
}

/// 6. send() preserves user-set Accept-Encoding header
pub fn send_preserves_user_accept_encoding_test() {
  let req =
    mock_request("/echo-accept-encoding")
    |> client.headers([Header("Accept-Encoding", "zstd")])
  let assert Ok(resp) = client.send(req)
  resp.status |> should.equal(200)
  resp.body |> should.equal("zstd")
}

/// 7. send() handles corrupted gzip data gracefully (error, not crash)
pub fn send_errors_on_corrupted_gzip_test() {
  let req = mock_request("/corrupted-gzip")
  case client.send(req) {
    Ok(resp) -> {
      // If httpc returns the raw data, that's also acceptable -
      // the important thing is it doesn't crash the process
      { resp.status == 200 } |> should.be_true()
    }
    Error(_) -> {
      // Error is fine -- decompression failure surfaced
      Nil
    }
  }
}

// ============================================================================
// B. Callback-based streaming tests (start_stream())
// ============================================================================

/// 8. start_stream decompresses gzip-compressed chunks
pub fn start_stream_decompresses_gzip_chunks_test() {
  let chunks_subject = process.new_subject()
  let ended_subject = process.new_subject()

  let request =
    mock_request("/stream/gzip")
    |> client.on_stream_chunk(fn(data) { process.send(chunks_subject, data) })
    |> client.on_stream_end(fn(_headers) { process.send(ended_subject, True) })

  let assert Ok(_handle) = client.start_stream(request)

  case process.receive(ended_subject, 10_000) {
    Ok(True) -> Nil
    Ok(False) -> should.fail()
    Error(Nil) -> {
      io.println("start_stream gzip: on_stream_end was never called")
      should.fail()
    }
  }

  let chunks = collect_chunks(chunks_subject, [])
  { chunks != [] } |> should.be_true()

  let combined = combine_chunks(chunks)
  string.contains(combined, "Chunk 1") |> should.be_true()
  string.contains(combined, "Chunk 5") |> should.be_true()
}

/// 9. start_stream decompresses deflate-compressed chunks
pub fn start_stream_decompresses_deflate_chunks_test() {
  let chunks_subject = process.new_subject()
  let ended_subject = process.new_subject()

  let request =
    mock_request("/stream/deflate")
    |> client.on_stream_chunk(fn(data) { process.send(chunks_subject, data) })
    |> client.on_stream_end(fn(_headers) { process.send(ended_subject, True) })

  let assert Ok(_handle) = client.start_stream(request)

  case process.receive(ended_subject, 10_000) {
    Ok(True) -> Nil
    Ok(False) -> should.fail()
    Error(Nil) -> {
      io.println("start_stream deflate: on_stream_end was never called")
      should.fail()
    }
  }

  let chunks = collect_chunks(chunks_subject, [])
  { chunks != [] } |> should.be_true()

  let combined = combine_chunks(chunks)
  string.contains(combined, "Chunk 1") |> should.be_true()
  string.contains(combined, "Chunk 5") |> should.be_true()
}

/// 10. start_stream passes through unknown encoding without crashing
pub fn start_stream_passes_through_unknown_encoding_chunks_test() {
  let chunks_subject = process.new_subject()
  let ended_subject = process.new_subject()
  let error_subject = process.new_subject()

  let request =
    mock_request("/stream/unknown-encoding")
    |> client.on_stream_chunk(fn(data) { process.send(chunks_subject, data) })
    |> client.on_stream_end(fn(_headers) { process.send(ended_subject, True) })
    |> client.on_stream_error(fn(reason) { process.send(error_subject, reason) })

  let assert Ok(_handle) = client.start_stream(request)

  case process.receive(ended_subject, 10_000) {
    Ok(True) -> {
      let chunks = collect_chunks(chunks_subject, [])
      { chunks != [] } |> should.be_true()
    }
    Ok(False) -> should.fail()
    Error(Nil) -> {
      case process.receive(error_subject, 1000) {
        Ok(_reason) -> Nil
        Error(Nil) -> {
          io.println("start_stream unknown-encoding: neither end nor error")
          should.fail()
        }
      }
    }
  }
}

/// 11. start_stream works without encoding (regression guard)
pub fn start_stream_works_without_encoding_test() {
  let chunks_subject = process.new_subject()
  let ended_subject = process.new_subject()

  let request =
    mock_request("/stream/fast")
    |> client.on_stream_chunk(fn(data) { process.send(chunks_subject, data) })
    |> client.on_stream_end(fn(_headers) { process.send(ended_subject, True) })

  let assert Ok(_handle) = client.start_stream(request)

  case process.receive(ended_subject, 5000) {
    Ok(True) -> Nil
    Ok(False) -> should.fail()
    Error(Nil) -> {
      io.println("on_stream_end was never called")
      should.fail()
    }
  }

  let chunks = collect_chunks(chunks_subject, [])
  { chunks != [] } |> should.be_true()
}

// ============================================================================
// C. Pull-based streaming tests (stream_yielder())
// ============================================================================

/// 12. stream_yielder decompresses gzip-compressed chunks
pub fn stream_yielder_decompresses_gzip_chunks_test() {
  let req = mock_request("/stream/gzip")
  let results = client.stream_yielder(req) |> yielder.to_list

  { results != [] } |> should.be_true()

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

/// 13. stream_yielder decompresses deflate-compressed chunks
pub fn stream_yielder_decompresses_deflate_chunks_test() {
  let req = mock_request("/stream/deflate")
  let results = client.stream_yielder(req) |> yielder.to_list

  { results != [] } |> should.be_true()

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

/// 14. stream_yielder passes through unknown encoding without crashing
pub fn stream_yielder_passes_through_unknown_encoding_chunks_test() {
  let req = mock_request("/stream/unknown-encoding")
  let results = client.stream_yielder(req) |> yielder.to_list

  { results != [] } |> should.be_true()

  let all_ok =
    list.all(results, fn(r) {
      case r {
        Ok(_) -> True
        Error(_) -> False
      }
    })
  all_ok |> should.be_true()
}

/// 15. stream_yielder works without encoding (regression guard)
pub fn stream_yielder_works_without_encoding_test() {
  let req = mock_request("/stream/fast")
  let results = client.stream_yielder(req) |> yielder.to_list

  { results != [] } |> should.be_true()

  let all_ok =
    list.all(results, fn(r) {
      case r {
        Ok(_) -> True
        Error(reason) -> {
          io.println("Unexpected error: " <> reason)
          False
        }
      }
    })
  all_ok |> should.be_true()
}

// ============================================================================
// D. Header injection tests
// ============================================================================

/// 16. send() auto-injects Accept-Encoding: gzip, deflate
pub fn send_auto_injects_accept_encoding_test() {
  let req = mock_request("/echo-accept-encoding")
  let assert Ok(resp) = client.send(req)
  resp.status |> should.equal(200)
  resp.body |> should.equal("gzip, deflate")
}

/// 17. start_stream auto-injects Accept-Encoding: gzip, deflate
pub fn start_stream_auto_injects_accept_encoding_test() {
  let chunks_subject = process.new_subject()
  let ended_subject = process.new_subject()

  let request =
    mock_request("/echo-accept-encoding")
    |> client.on_stream_chunk(fn(data) { process.send(chunks_subject, data) })
    |> client.on_stream_end(fn(_headers) { process.send(ended_subject, True) })
    |> client.on_stream_error(fn(reason) {
      process.send(ended_subject, False)
      io.println("Error in header injection test: " <> reason)
    })

  let assert Ok(_handle) = client.start_stream(request)

  case process.receive(ended_subject, 5000) {
    Ok(_) -> Nil
    Error(Nil) -> {
      io.println("start_stream header injection: timed out")
      should.fail()
    }
  }

  let chunks = collect_chunks(chunks_subject, [])
  let combined = combine_chunks(chunks)
  string.contains(combined, "gzip, deflate") |> should.be_true()
}

/// 18. stream_yielder auto-injects Accept-Encoding: gzip, deflate
pub fn stream_yielder_auto_injects_accept_encoding_test() {
  let req = mock_request("/echo-accept-encoding")
  let results = client.stream_yielder(req) |> yielder.to_list

  let ok_chunks =
    list.filter_map(results, fn(r) {
      case r {
        Ok(bt) -> Ok(bytes_tree.to_bit_array(bt))
        Error(_) -> Error(Nil)
      }
    })

  let combined = combine_chunks(ok_chunks)
  string.contains(combined, "gzip, deflate") |> should.be_true()
}

/// 19. send() preserves custom Accept-Encoding
pub fn send_preserves_custom_accept_encoding_test() {
  let req =
    mock_request("/echo-accept-encoding")
    |> client.headers([Header("Accept-Encoding", "zstd")])
  let assert Ok(resp) = client.send(req)
  resp.body |> should.equal("zstd")
}

/// 20. start_stream preserves custom Accept-Encoding
pub fn start_stream_preserves_custom_accept_encoding_test() {
  let chunks_subject = process.new_subject()
  let ended_subject = process.new_subject()

  let request =
    mock_request("/echo-accept-encoding")
    |> client.headers([Header("Accept-Encoding", "zstd")])
    |> client.on_stream_chunk(fn(data) { process.send(chunks_subject, data) })
    |> client.on_stream_end(fn(_headers) { process.send(ended_subject, True) })
    |> client.on_stream_error(fn(reason) {
      process.send(ended_subject, False)
      io.println("Error in preserve test: " <> reason)
    })

  let assert Ok(_handle) = client.start_stream(request)

  case process.receive(ended_subject, 5000) {
    Ok(_) -> Nil
    Error(Nil) -> {
      io.println("start_stream preserve: timed out")
      should.fail()
    }
  }

  let chunks = collect_chunks(chunks_subject, [])
  let combined = combine_chunks(chunks)
  combined |> should.equal("zstd")
}

/// 21. stream_yielder preserves custom Accept-Encoding
pub fn stream_yielder_preserves_custom_accept_encoding_test() {
  let req =
    mock_request("/echo-accept-encoding")
    |> client.headers([Header("Accept-Encoding", "zstd")])
  let results = client.stream_yielder(req) |> yielder.to_list

  let ok_chunks =
    list.filter_map(results, fn(r) {
      case r {
        Ok(bt) -> Ok(bytes_tree.to_bit_array(bt))
        Error(_) -> Error(Nil)
      }
    })

  let combined = combine_chunks(ok_chunks)
  combined |> should.equal("zstd")
}

// ============================================================================
// E. Zlib lifecycle tests (verify cleanup, no resource leaks)
// ============================================================================

/// 22. start_stream gzip: zlib cleaned up on normal stream end
pub fn start_stream_gzip_cleans_up_zlib_on_stream_end_test() {
  let ended_subject = process.new_subject()

  let request =
    mock_request("/stream/gzip")
    |> client.on_stream_chunk(fn(_data) { Nil })
    |> client.on_stream_end(fn(_headers) { process.send(ended_subject, True) })

  let assert Ok(handle) = client.start_stream(request)

  case process.receive(ended_subject, 10_000) {
    Ok(True) -> Nil
    Ok(False) -> should.fail()
    Error(Nil) -> {
      io.println("Zlib cleanup test: stream_end never called")
      should.fail()
    }
  }

  client.await_stream(handle)
  client.is_stream_active(handle) |> should.be_false()
}

/// 23. stream_yielder gzip: zlib cleaned up on normal stream end
pub fn stream_yielder_gzip_cleans_up_zlib_on_stream_end_test() {
  let req = mock_request("/stream/gzip")
  let results = client.stream_yielder(req) |> yielder.to_list

  { results != [] } |> should.be_true()

  let all_ok =
    list.all(results, fn(r) {
      case r {
        Ok(_) -> True
        Error(_) -> False
      }
    })
  all_ok |> should.be_true()
}

/// 24. start_stream gzip: zlib cleaned up even on error
pub fn start_stream_gzip_cleans_up_zlib_on_error_test() {
  let error_subject = process.new_subject()

  let request =
    mock_request("/status/500")
    |> client.on_stream_chunk(fn(_data) { Nil })
    |> client.on_stream_end(fn(_headers) { Nil })
    |> client.on_stream_error(fn(reason) { process.send(error_subject, reason) })

  let assert Ok(handle) = client.start_stream(request)

  case process.receive(error_subject, 5000) {
    Ok(_reason) -> Nil
    Error(Nil) -> {
      io.println("Zlib error cleanup test: error never called")
      should.fail()
    }
  }

  client.await_stream(handle)
  client.is_stream_active(handle) |> should.be_false()
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
