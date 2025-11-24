//// stream_controller.gleam - Mock streaming endpoints
////
//// Provides various streaming endpoints for testing Dream's HTTP client.
//// Each endpoint demonstrates different streaming behaviors and patterns.

import dream/context.{type EmptyContext}
import dream/http/request.{type Request}
import dream/http/response.{type Response, stream_response, text_response}
import dream/http/status
import dream/router.{type EmptyServices}
import dream_mock_server/views/index_view
import gleam/bit_array
import gleam/erlang/process
import gleam/int
import gleam/json
import gleam/list
import gleam/yielder

/// Index action - displays available endpoints (streaming and non-streaming)
pub fn index(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  text_response(status.ok, index_view.format_index())
}

/// Fast streaming - 10 chunks at 100ms intervals
///
/// Demonstrates fast streaming for testing quick response handling.
pub fn stream_fast(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  let stream =
    yielder.range(1, 10)
    |> yielder.map(create_fast_chunk)

  stream_response(status.ok, stream, "text/plain")
}

fn create_fast_chunk(n: Int) -> BitArray {
  process.sleep(100)
  let line = "Chunk " <> int.to_string(n) <> "\n"
  bit_array.from_string(line)
}

/// Slow streaming - 5 chunks at 2s intervals
///
/// Demonstrates slow streaming for testing timeout handling.
pub fn stream_slow(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  let stream =
    yielder.range(1, 5)
    |> yielder.map(create_slow_chunk)

  stream_response(status.ok, stream, "text/plain")
}

fn create_slow_chunk(n: Int) -> BitArray {
  process.sleep(2000)
  let line = "Chunk " <> int.to_string(n) <> "\n"
  bit_array.from_string(line)
}

/// Burst streaming - Random burst pattern with 5-10 chunks
///
/// Demonstrates variable chunk count and timing for testing robustness.
pub fn stream_burst(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  // Fixed pattern: 7 chunks with varying delays for deterministic testing
  let delays = [100, 500, 200, 400, 100, 300, 200]

  let stream =
    list.index_map(delays, create_indexed_delay)
    |> yielder.from_list
    |> yielder.map(create_burst_chunk)

  stream_response(status.ok, stream, "text/plain")
}

fn create_indexed_delay(delay: Int, idx: Int) -> #(Int, Int) {
  #(idx + 1, delay)
}

fn create_burst_chunk(pair: #(Int, Int)) -> BitArray {
  let #(n, delay) = pair
  process.sleep(delay)
  let line = "Burst " <> int.to_string(n) <> "\n"
  bit_array.from_string(line)
}

/// Error streaming - 3 chunks then fails
///
/// Demonstrates error handling mid-stream.
/// Note: This returns a 500 status but still sends some chunks first.
pub fn stream_error(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  let stream =
    yielder.range(1, 3)
    |> yielder.map(create_error_chunk)

  // Return 500 status with partial content to simulate mid-stream error
  stream_response(status.internal_server_error, stream, "text/plain")
}

fn create_error_chunk(n: Int) -> BitArray {
  process.sleep(100)
  let line = "Error test chunk " <> int.to_string(n) <> "\n"
  bit_array.from_string(line)
}

/// Huge streaming - 100 chunks for memory/performance testing
///
/// Demonstrates large response streaming.
pub fn stream_huge(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  let stream =
    yielder.range(1, 100)
    |> yielder.map(create_huge_chunk)

  stream_response(status.ok, stream, "text/plain")
}

fn create_huge_chunk(n: Int) -> BitArray {
  process.sleep(10)
  let line = "Huge chunk " <> int.to_string(n) <> "\n"
  bit_array.from_string(line)
}

/// JSON streaming - Stream of JSON objects
///
/// Demonstrates structured data streaming.
pub fn stream_json(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  let stream =
    yielder.range(1, 5)
    |> yielder.map(create_json_chunk)

  stream_response(status.ok, stream, "application/json")
}

fn create_json_chunk(n: Int) -> BitArray {
  process.sleep(200)
  let json_obj =
    json.object([
      #("event", json.string("chunk")),
      #("number", json.int(n)),
      #("message", json.string("JSON event " <> int.to_string(n))),
    ])
    |> json.to_string
  bit_array.from_string(json_obj <> "\n")
}

/// Binary streaming - Raw binary data
///
/// Demonstrates non-text streaming.
pub fn stream_binary(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  let stream =
    yielder.range(0, 255)
    |> yielder.map(create_binary_chunk)

  stream_response(status.ok, stream, "application/octet-stream")
}

fn create_binary_chunk(n: Int) -> BitArray {
  process.sleep(10)
  // Create a binary chunk with repeating byte pattern
  <<n:8, n:8, n:8, n:8>>
}
