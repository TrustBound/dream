//// Recording format types and JSON codecs
////
//// Defines the structure for storing HTTP request/response recordings
//// in a custom JSON format that supports both blocking and streaming responses.

import gleam/bit_array
import gleam/dynamic/decode
import gleam/http
import gleam/io
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string

/// Recorded HTTP request
pub type RecordedRequest {
  RecordedRequest(
    method: http.Method,
    scheme: http.Scheme,
    host: String,
    port: option.Option(Int),
    path: String,
    query: option.Option(String),
    headers: List(#(String, String)),
    body: String,
  )
}

/// Recorded HTTP response - can be blocking or streaming
pub type RecordedResponse {
  BlockingResponse(status: Int, headers: List(#(String, String)), body: String)
  StreamingResponse(
    status: Int,
    headers: List(#(String, String)),
    chunks: List(Chunk),
  )
}

/// Streaming chunk with timing information
pub type Chunk {
  Chunk(data: BitArray, delay_ms: Int)
}

/// Complete recording entry (request + response pair)
pub type Recording {
  Recording(request: RecordedRequest, response: RecordedResponse)
}

/// Recording file format (versioned)
pub type RecordingFile {
  RecordingFile(version: String, entries: List(Recording))
}

// ============================================================================
// JSON Encoders
// ============================================================================

/// Encode a `RecordingFile` to JSON
///
/// This helper converts an in-memory `RecordingFile` value into a `json.Json`
/// tree that can be rendered to a string and written to disk. It is used by
/// the storage module when persisting recordings.
///
/// Most callers should use `storage.save_recordings/2` instead of calling this
/// function directly.
pub fn encode_recording_file(file: RecordingFile) -> json.Json {
  let entries_json = list.map(file.entries, encode_recording)
  json.object([
    #("version", json.string(file.version)),
    #("entries", json.array(from: entries_json, of: identity_json)),
  ])
}

fn identity_json(value: json.Json) -> json.Json {
  value
}

fn encode_recording(recording: Recording) -> json.Json {
  json.object([
    #("request", encode_recorded_request(recording.request)),
    #("response", encode_recorded_response(recording.response)),
  ])
}

fn encode_recorded_request(req: RecordedRequest) -> json.Json {
  let port_json = case req.port {
    option.Some(p) -> json.int(p)
    option.None -> json.null()
  }
  let query_json = case req.query {
    option.Some(q) -> json.string(q)
    option.None -> json.null()
  }
  json.object([
    #("method", encode_method(req.method)),
    #("scheme", encode_scheme(req.scheme)),
    #("host", json.string(req.host)),
    #("port", port_json),
    #("path", json.string(req.path)),
    #("query", query_json),
    #("headers", encode_headers(req.headers)),
    #("body", json.string(req.body)),
  ])
}

fn encode_recorded_response(resp: RecordedResponse) -> json.Json {
  case resp {
    BlockingResponse(status, headers, body) ->
      json.object([
        #("mode", json.string("blocking")),
        #("status", json.int(status)),
        #("headers", encode_headers(headers)),
        #("body", json.string(body)),
      ])
    StreamingResponse(status, headers, chunks) -> {
      let chunks_json = list.map(chunks, encode_chunk)
      json.object([
        #("mode", json.string("streaming")),
        #("status", json.int(status)),
        #("headers", encode_headers(headers)),
        #("chunks", json.array(from: chunks_json, of: identity_json)),
      ])
    }
  }
}

fn encode_chunk(chunk: Chunk) -> json.Json {
  // Convert BitArray to string for JSON storage
  // We'll store as UTF-8 string, which works for text data
  // For binary data, we'd need base64, but BitArray doesn't have that
  // For now, convert to string and handle encoding errors gracefully
  let data_str = case bit_array.to_string(chunk.data) {
    Ok(string_value) -> string_value
    Error(utf8_decode_error) -> {
      // If conversion fails, log the decode error and use a placeholder. In
      // practice, streaming chunks are usually text, so this is rare.
      io.println_error(
        "Failed to encode recording chunk as UTF-8 string: "
        <> string.inspect(utf8_decode_error),
      )
      ""
    }
  }
  json.object([
    #("data", json.string(data_str)),
    #("delay_ms", json.int(chunk.delay_ms)),
  ])
}

fn encode_headers(headers: List(#(String, String))) -> json.Json {
  let header_arrays = list.map(headers, encode_header_pair)
  json.array(from: header_arrays, of: identity_json)
}

fn encode_header_pair(header: #(String, String)) -> json.Json {
  json.array(
    from: [json.string(header.0), json.string(header.1)],
    of: identity_json,
  )
}

fn encode_method(method: http.Method) -> json.Json {
  let method_str = case method {
    http.Get -> "GET"
    http.Post -> "POST"
    http.Put -> "PUT"
    http.Delete -> "DELETE"
    http.Patch -> "PATCH"
    http.Head -> "HEAD"
    http.Options -> "OPTIONS"
    http.Trace -> "TRACE"
    http.Connect -> "CONNECT"
    http.Other(s) -> string.uppercase(s)
  }
  json.string(method_str)
}

fn encode_scheme(scheme: http.Scheme) -> json.Json {
  let scheme_str = case scheme {
    http.Http -> "http"
    http.Https -> "https"
  }
  json.string(scheme_str)
}

// ============================================================================
// JSON Decoders
// ============================================================================

/// Decode a JSON string into a `RecordingFile`
///
/// Parses the given JSON string and attempts to decode it into a
/// `RecordingFile` value. This is the inverse of `encode_recording_file/1` and
/// is used by the storage module when loading recordings from disk.
///
/// On success, returns the decoded `RecordingFile`. On failure, returns a
/// human-readable error message describing why the JSON could not be parsed or
/// decoded.
pub fn decode_recording_file(
  json_string: String,
) -> Result(RecordingFile, String) {
  use json_value <- result.try(
    json.parse(json_string, decode.dynamic)
    |> result.map_error(format_json_error),
  )
  decode.run(json_value, decode_recording_file_decoder())
  |> result.map_error(format_decode_errors)
}

fn decode_recording_file_decoder() -> decode.Decoder(RecordingFile) {
  use version <- decode.field("version", decode.string)
  use entries <- decode.field(
    "entries",
    decode.list(decode_recording_decoder()),
  )
  decode.success(RecordingFile(version: version, entries: entries))
}

fn format_json_error(error: json.DecodeError) -> String {
  case error {
    json.UnexpectedEndOfInput -> "Unexpected end of JSON input"
    json.UnexpectedByte(msg) -> "Unexpected byte: " <> msg
    json.UnexpectedSequence(msg) -> "Unexpected sequence: " <> msg
    json.UnableToDecode(errors) ->
      "Unable to decode: " <> string.inspect(errors)
  }
}

fn format_decode_errors(errors: List(decode.DecodeError)) -> String {
  case list.first(errors) {
    Ok(error) -> format_single_decode_error(error)
    Error(empty_list_error) -> {
      // We did not get any concrete decode errors back; log that situation so
      // it is visible when troubleshooting.
      io.println_error(
        "Decode error with no details in recording file: "
        <> string.inspect(empty_list_error),
      )
      "Decode error with no details"
    }
  }
}

fn format_single_decode_error(error: decode.DecodeError) -> String {
  let decode.DecodeError(expected, found, path) = error
  let field_path = string.join(path, ".")
  "Expected " <> expected <> ", found " <> found <> " at " <> field_path
}

fn decode_recording_decoder() -> decode.Decoder(Recording) {
  use request <- decode.field("request", decode_recorded_request_decoder())
  use response <- decode.field("response", decode_recorded_response_decoder())
  decode.success(Recording(request: request, response: response))
}

fn decode_recorded_request_decoder() -> decode.Decoder(RecordedRequest) {
  use method_str <- decode.field("method", decode.string)
  use scheme_str <- decode.field("scheme", decode.string)
  use host <- decode.field("host", decode.string)
  use port <- decode.field("port", decode.optional(decode.int))
  use path <- decode.field("path", decode.string)
  use query <- decode.field("query", decode.optional(decode.string))
  use headers <- decode.field(
    "headers",
    decode.list(decode_header_pair_decoder()),
  )
  use body <- decode.field("body", decode.string)

  // Parse method and scheme
  // Method: Use Other() for unknown methods (preserves original value)
  // Scheme: Fail on unknown schemes (only http/https are valid)
  let method = case parse_method_string(method_str) {
    Ok(parsed_method) -> parsed_method
    Error(parse_error) -> {
      // Preserve the original method string but log the parse error so it is
      // not silently discarded.
      io.println_error(
        "Failed to parse HTTP method in recording: " <> parse_error,
      )
      http.Other(method_str)
    }
  }

  case parse_scheme_string(scheme_str) {
    Ok(scheme) ->
      decode.success(RecordedRequest(
        method: method,
        scheme: scheme,
        host: host,
        port: port,
        path: path,
        query: query,
        headers: headers,
        body: body,
      ))
    Error(parse_error) -> {
      // Invalid scheme in recording - fall back to http and log the error so
      // it is visible when inspecting corrupted recording files.
      io.println_error(
        "Unknown scheme in recording; defaulting to http: " <> parse_error,
      )
      decode.success(RecordedRequest(
        method: method,
        scheme: http.Http,
        host: host,
        port: port,
        path: path,
        query: query,
        headers: headers,
        body: body,
      ))
    }
  }
}

fn decode_recorded_response_decoder() -> decode.Decoder(RecordedResponse) {
  use mode <- decode.field("mode", decode.string)
  use status <- decode.field("status", decode.int)
  use headers <- decode.field(
    "headers",
    decode.list(decode_header_pair_decoder()),
  )

  case mode {
    "blocking" -> decode_blocking_response_decoder(status, headers)
    "streaming" -> decode_streaming_response_decoder(status, headers)
    _ -> decode_blocking_response_decoder(status, headers)
  }
}

fn decode_blocking_response_decoder(
  status: Int,
  headers: List(#(String, String)),
) -> decode.Decoder(RecordedResponse) {
  use body <- decode.field("body", decode.string)
  decode.success(BlockingResponse(status: status, headers: headers, body: body))
}

fn decode_streaming_response_decoder(
  status: Int,
  headers: List(#(String, String)),
) -> decode.Decoder(RecordedResponse) {
  use chunks <- decode.field("chunks", decode.list(decode_chunk_decoder()))
  decode.success(StreamingResponse(
    status: status,
    headers: headers,
    chunks: chunks,
  ))
}

fn decode_chunk_decoder() -> decode.Decoder(Chunk) {
  use data_str <- decode.field("data", decode.string)
  use delay_ms <- decode.field("delay_ms", decode.int)
  // Convert string back to BitArray
  let data = <<data_str:utf8>>
  decode.success(Chunk(data: data, delay_ms: delay_ms))
}

fn decode_header_pair_decoder() -> decode.Decoder(#(String, String)) {
  decode.at([0], decode.string)
  |> decode.then(build_header_value_decoder)
}

fn build_header_value_decoder(name: String) -> decode.Decoder(#(String, String)) {
  decode.at([1], decode.string)
  |> decode.map(build_header_pair(name))
}

fn build_header_pair(name: String) -> fn(String) -> #(String, String) {
  fn(value) { #(name, value) }
}

fn parse_method_string(method_str: String) -> Result(http.Method, String) {
  case string.lowercase(method_str) {
    "get" -> Ok(http.Get)
    "post" -> Ok(http.Post)
    "put" -> Ok(http.Put)
    "delete" -> Ok(http.Delete)
    "patch" -> Ok(http.Patch)
    "head" -> Ok(http.Head)
    "options" -> Ok(http.Options)
    "trace" -> Ok(http.Trace)
    "connect" -> Ok(http.Connect)
    _ -> Ok(http.Other(method_str))
  }
}

fn parse_scheme_string(scheme_str: String) -> Result(http.Scheme, String) {
  case scheme_str {
    "http" -> Ok(http.Http)
    "https" -> Ok(http.Https)
    _ -> Error("Unknown scheme: " <> scheme_str)
  }
}
