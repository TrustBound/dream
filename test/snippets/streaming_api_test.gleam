//// Tests for the snippets shown in docs/reference/streaming-api.md.

import dream/dream
import dream/http/header.{Header}
import dream/http/request.{type Request, Get, Post, Put, Request}
import dream/http/response.{type Response, Bytes, Stream, Text}
import dream/router.{route, router}
import dream/servers/mist/server
import dream/servers/mist/sse
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}
import fixtures/request as test_request
import gleam/bit_array
import gleam/option.{None, Some}
import gleam/yielder
import matchers/extract_body_text.{extract_body_text}
import matchers/extract_response_status.{extract_response_status}
import snippets/streaming_api_responses
import snippets/streaming_api_routing
import snippets/streaming_api_signatures
import snippets/streaming_api_sse
import snippets/streaming_api_types
import snippets/streaming_api_yielder

pub fn tests() -> UnitTest {
  describe("streaming api snippets", [
    types_tests(),
    signatures_tests(),
    responses_tests(),
    yielder_tests(),
    routing_tests(),
    sse_tests(),
  ])
}

// ============================================================================
// Types
// ============================================================================

fn types_tests() -> UnitTest {
  describe("types", [
    it("create_upload_request has an empty buffered body", fn() {
      // Arrange
      let chunks = yielder.from_list([<<"abc":utf8>>])

      // Act
      let request = streaming_api_types.create_upload_request(chunks)

      // Assert
      request.body
      |> should()
      |> equal("")
      |> or_fail_with("body should be empty")
    }),
    it("create_upload_request holds the chunks in stream", fn() {
      // Arrange
      let chunks = yielder.from_list([<<"ab":utf8>>, <<"c":utf8>>])

      // Act
      let request = streaming_api_types.create_upload_request(chunks)

      // Assert
      request_stream_body(request)
      |> should()
      |> equal(<<"abc":utf8>>)
      |> or_fail_with("stream should hold 'abc'")
    }),
    it("describe_body names a Text body", fn() {
      // Act
      let description = streaming_api_types.describe_body(Text("hello"))

      // Assert
      description
      |> should()
      |> equal("buffered text")
      |> or_fail_with("Text should be 'buffered text'")
    }),
    it("describe_body names a Bytes body", fn() {
      // Act
      let description = streaming_api_types.describe_body(Bytes(<<1>>))

      // Assert
      description
      |> should()
      |> equal("buffered bytes")
      |> or_fail_with("Bytes should be 'buffered bytes'")
    }),
    it("describe_body names a Stream body", fn() {
      // Act
      let description =
        streaming_api_types.describe_body(Stream(yielder.empty()))

      // Assert
      description
      |> should()
      |> equal("stream")
      |> or_fail_with("Stream should be 'stream'")
    }),
    it("create_csv_export_response streams the rows", fn() {
      // Arrange
      let rows = yielder.from_list([<<"a,b\n":utf8>>, <<"1,2\n":utf8>>])

      // Act
      let response = streaming_api_types.create_csv_export_response(rows)

      // Assert
      stream_body(response)
      |> should()
      |> equal(<<"a,b\n1,2\n":utf8>>)
      |> or_fail_with("response should stream the rows")
    }),
  ])
}

// ============================================================================
// Signatures
// ============================================================================

fn signatures_tests() -> UnitTest {
  describe("signatures", [
    it("stream_response sets the content type", fn() {
      // Arrange
      let stream = yielder.from_list([<<"a":utf8>>])

      // Act
      let response =
        streaming_api_signatures.stream_response(200, stream, "text/csv")

      // Assert
      response.content_type
      |> should()
      |> equal(Some("text/csv"))
      |> or_fail_with("content type should be text/csv")
    }),
    it("sse_response sets the content type", fn() {
      // Arrange
      let stream = yielder.from_list([<<"data: a\n\n":utf8>>])

      // Act
      let response =
        streaming_api_signatures.sse_response(200, stream, "text/event-stream")

      // Assert
      response.content_type
      |> should()
      |> equal(Some("text/event-stream"))
      |> or_fail_with("content type should be text/event-stream")
    }),
    it("upgrade_to_sse is sse.upgrade_to_sse", fn() {
      // Act
      let same = streaming_api_signatures.upgrade_to_sse == sse.upgrade_to_sse

      // Assert
      same
      |> should()
      |> equal(True)
      |> or_fail_with("constant should hold sse.upgrade_to_sse")
    }),
    it("send_event is sse.send_event", fn() {
      // Act
      let same = streaming_api_signatures.send_event == sse.send_event

      // Assert
      same
      |> should()
      |> equal(True)
      |> or_fail_with("constant should hold sse.send_event")
    }),
    it("event builds the same event as sse.event", fn() {
      // Act
      let event = streaming_api_signatures.event("hello")

      // Assert
      event
      |> should()
      |> equal(sse.event("hello"))
      |> or_fail_with("event should equal sse.event")
    }),
    it("event_name builds the same event as sse.event_name", fn() {
      // Act
      let event = streaming_api_signatures.event_name(sse.event("a"), "tick")

      // Assert
      event
      |> should()
      |> equal(sse.event_name(sse.event("a"), "tick"))
      |> or_fail_with("event_name should equal sse.event_name")
    }),
    it("event_id builds the same event as sse.event_id", fn() {
      // Act
      let event = streaming_api_signatures.event_id(sse.event("a"), "7")

      // Assert
      event
      |> should()
      |> equal(sse.event_id(sse.event("a"), "7"))
      |> or_fail_with("event_id should equal sse.event_id")
    }),
    it("event_retry builds the same event as sse.event_retry", fn() {
      // Act
      let event = streaming_api_signatures.event_retry(sse.event("a"), 5000)

      // Assert
      event
      |> should()
      |> equal(sse.event_retry(sse.event("a"), 5000))
      |> or_fail_with("event_retry should equal sse.event_retry")
    }),
    it("continue_connection builds the same action", fn() {
      // Act
      let action: sse.Action(Int, String) =
        streaming_api_signatures.continue_connection(1)

      // Assert
      action
      |> should()
      |> equal(sse.continue_connection(1))
      |> or_fail_with("continue_connection should equal sse version")
    }),
    it("stop_connection builds the same action", fn() {
      // Act
      let action: sse.Action(Int, String) =
        streaming_api_signatures.stop_connection()

      // Assert
      action
      |> should()
      |> equal(sse.stop_connection())
      |> or_fail_with("stop_connection should equal sse version")
    }),
    it("stream_route adds a route that gets the stream", fn() {
      // Arrange
      let app_router =
        streaming_api_signatures.stream_route(
          router(),
          Post,
          "/upload",
          streaming_api_routing.upload,
          [],
        )
      let request =
        test_request.create_streaming_request_from_strings(Post, "/upload", [
          "ab", "cd",
        ])

      // Act
      let response = dream.route_request(app_router, request, Nil, Nil)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("Received 4 bytes")
      |> or_fail_with("upload should receive 4 bytes")
    }),
    it("route adds a buffered route", fn() {
      // Arrange
      let app_router =
        streaming_api_signatures.route(
          router(),
          Get,
          "/report",
          streaming_api_routing.replace_file,
          [],
        )
      let request = test_request.create_request(Get, "/report")

      // Act
      let response = dream.route_request(app_router, request, Nil, Nil)

      // Assert
      response
      |> should()
      |> extract_response_status()
      |> equal(200)
      |> or_fail_with("route should answer 200")
    }),
    it("max_body_size sets the limit", fn() {
      // Act
      let app = streaming_api_signatures.max_body_size(server.new(), 5000)

      // Assert
      dream.get_max_body_size(app)
      |> should()
      |> equal(5000)
      |> or_fail_with("max body size should be 5000")
    }),
  ])
}

// ============================================================================
// Responses
// ============================================================================

fn responses_tests() -> UnitTest {
  describe("responses", [
    it("download streams 1000 bytes", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/download")

      // Act
      let response = streaming_api_responses.download(request, Nil, Nil)

      // Assert
      bit_array.byte_size(stream_body(response))
      |> should()
      |> equal(1000)
      |> or_fail_with("download should stream 1000 bytes")
    }),
    it("create_buffered_report holds every line", fn() {
      // Act
      let response = streaming_api_responses.create_buffered_report(2)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("report line\nreport line\n")
      |> or_fail_with("buffered report should hold two lines")
    }),
    it("create_streamed_report streams every line", fn() {
      // Act
      let response = streaming_api_responses.create_streamed_report(2)

      // Assert
      stream_body(response)
      |> should()
      |> equal(<<"report line\nreport line\n":utf8>>)
      |> or_fail_with("streamed report should stream two lines")
    }),
    it("upload counts the bytes of a valid stream", fn() {
      // Arrange
      let request =
        test_request.create_streaming_request_from_strings(Post, "/upload", [
          "ab", "cde",
        ])

      // Act
      let response = streaming_api_responses.upload(request, Nil, Nil)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("Processed 5 bytes")
      |> or_fail_with("upload should process 5 bytes")
    }),
    it("upload returns 422 for a chunk that is not UTF-8", fn() {
      // Arrange
      let stream = yielder.from_list([<<"ab":utf8>>, <<255>>])
      let request =
        test_request.create_streaming_request(Post, "/upload", stream)

      // Act
      let response = streaming_api_responses.upload(request, Nil, Nil)

      // Assert
      response
      |> should()
      |> extract_response_status()
      |> equal(422)
      |> or_fail_with("upload should return 422")
    }),
    it("upload returns 400 without a stream", fn() {
      // Arrange
      let request = test_request.create_request(Post, "/upload")

      // Act
      let response = streaming_api_responses.upload(request, Nil, Nil)

      // Assert
      response
      |> should()
      |> extract_response_status()
      |> equal(400)
      |> or_fail_with("upload should return 400")
    }),
  ])
}

// ============================================================================
// Yielder operations
// ============================================================================

fn yielder_tests() -> UnitTest {
  describe("yielder operations", [
    it("uppercase_stream uppercases every chunk", fn() {
      // Arrange
      let stream = yielder.from_list([<<"ab":utf8>>, <<"c":utf8>>])

      // Act
      let result = streaming_api_yielder.uppercase_stream(stream)

      // Assert
      bit_array.concat(yielder.to_list(result))
      |> should()
      |> equal(<<"ABC":utf8>>)
      |> or_fail_with("stream should be 'ABC'")
    }),
    it("remove_empty_chunks drops empty chunks", fn() {
      // Arrange
      let stream = yielder.from_list([<<"a":utf8>>, <<>>, <<"b":utf8>>])

      // Act
      let result = streaming_api_yielder.remove_empty_chunks(stream)

      // Assert
      yielder.to_list(result)
      |> should()
      |> equal([<<"a":utf8>>, <<"b":utf8>>])
      |> or_fail_with("only non-empty chunks should stay")
    }),
    it("count_total_bytes adds the chunk sizes", fn() {
      // Arrange
      let stream = yielder.from_list([<<"ab":utf8>>, <<"cde":utf8>>])

      // Act
      let total = streaming_api_yielder.count_total_bytes(stream)

      // Assert
      total
      |> should()
      |> equal(5)
      |> or_fail_with("total should be 5")
    }),
    it("take_first_chunks keeps 100 chunks", fn() {
      // Arrange
      let stream = yielder.range(1, 150) |> yielder.map(fn(_n) { <<1>> })

      // Act
      let result = streaming_api_yielder.take_first_chunks(stream)

      // Assert
      yielder.length(result)
      |> should()
      |> equal(100)
      |> or_fail_with("100 chunks should stay")
    }),
    it("create_csv_stream puts the header first", fn() {
      // Act
      let result = streaming_api_yielder.create_csv_stream(["Ada", "Bo"])

      // Assert
      bit_array.concat(yielder.to_list(result))
      |> should()
      |> equal(<<"name\nAda\nBo\n":utf8>>)
      |> or_fail_with("CSV should be header then rows")
    }),
  ])
}

// ============================================================================
// Routing and middleware
// ============================================================================

fn routing_tests() -> UnitTest {
  describe("routing", [
    it("POST /upload receives the stream", fn() {
      // Arrange
      let request =
        test_request.create_streaming_request_from_strings(Post, "/upload", [
          "abc",
        ])

      // Act
      let response =
        dream.route_request(
          streaming_api_routing.create_router(),
          request,
          Nil,
          Nil,
        )

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("Received 3 bytes")
      |> or_fail_with("upload should receive 3 bytes")
    }),
    it("PUT /files/:id without an API key returns 401", fn() {
      // Arrange
      let request =
        test_request.create_streaming_request_from_strings(Put, "/files/7", [
          "abc",
        ])

      // Act
      let response =
        dream.route_request(
          streaming_api_routing.create_router(),
          request,
          Nil,
          Nil,
        )

      // Assert
      response
      |> should()
      |> extract_response_status()
      |> equal(401)
      |> or_fail_with("missing API key should return 401")
    }),
    it("PUT /files/:id with an API key replaces the file", fn() {
      // Arrange
      let request =
        Request(
          ..test_request.create_streaming_request_from_strings(Put, "/files/7", [
            "abc",
          ]),
          headers: [Header("X-Api-Key", "secret")],
        )

      // Act
      let response =
        dream.route_request(
          streaming_api_routing.create_router(),
          request,
          Nil,
          Nil,
        )

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("File replaced")
      |> or_fail_with("API key should let the request through")
    }),
    it("uppercase_incoming uppercases the request stream", fn() {
      // Arrange
      let request =
        test_request.create_streaming_request_from_strings(Post, "/upload", [
          "ab", "c",
        ])

      // Act
      let response =
        streaming_api_routing.uppercase_incoming(
          request,
          Nil,
          Nil,
          echo_request_stream,
        )

      // Assert
      stream_body(response)
      |> should()
      |> equal(<<"ABC":utf8>>)
      |> or_fail_with("next should get 'ABC'")
    }),
    it("end_outgoing_chunks_with_newline ends each chunk with a newline", fn() {
      // Arrange
      let request =
        test_request.create_streaming_request_from_strings(Post, "/upload", [
          "a", "b",
        ])

      // Act
      let response =
        streaming_api_routing.end_outgoing_chunks_with_newline(
          request,
          Nil,
          Nil,
          echo_request_stream,
        )

      // Assert
      stream_body(response)
      |> should()
      |> equal(<<"a\nb\n":utf8>>)
      |> or_fail_with("response should stream 'a\\nb\\n'")
    }),
    it("create_large_payload_server sets a 100MB limit", fn() {
      // Act
      let app = streaming_api_routing.create_large_payload_server()

      // Assert
      dream.get_max_body_size(app)
      |> should()
      |> equal(100_000_000)
      |> or_fail_with("limit should be 100_000_000")
    }),
  ])
}

// ============================================================================
// Server-Sent Events
// ============================================================================

fn sse_tests() -> UnitTest {
  describe("server-sent events", [
    it("handle_events sends two tick events", fn() {
      // Arrange
      let app_router =
        router()
        |> route(
          method: Get,
          path: "/events",
          controller: streaming_api_sse.handle_events,
          middleware: [],
        )

      // Act
      let body = request_events(app_router, free_port())

      // Assert
      body
      |> should()
      |> equal(Ok(
        "retry: 5000\nid: 0\nevent: tick\ndata: {\"count\": 0}\n\n"
        <> "retry: 5000\nid: 1\nevent: tick\ndata: {\"count\": 1}\n\n",
      ))
      |> or_fail_with("handle_events should send two tick events")
    }),
  ])
}

// ============================================================================
// Helpers
// ============================================================================

fn stream_body(response: Response) -> BitArray {
  case response.body {
    Stream(stream) -> stream |> yielder.to_list |> bit_array.concat
    _other -> <<>>
  }
}

fn request_stream_body(request: Request) -> BitArray {
  case request.stream {
    Some(stream) -> stream |> yielder.to_list |> bit_array.concat
    None -> <<>>
  }
}

fn echo_request_stream(request: Request, _context, _services) -> Response {
  let stream = option.unwrap(request.stream, yielder.empty())
  response.stream_response(200, stream, "text/plain")
}

/// Starts a server, sends GET /events, and returns the response body once it
/// holds two complete events.
fn request_events(app_router, port: Int) -> Result(String, String) {
  let started =
    server.new()
    |> server.router(app_router)
    |> server.bind("127.0.0.1")
    |> server.listen_with_handle(port)
  case started {
    Ok(handle) -> {
      let body =
        read_events(
          port,
          <<"GET /events HTTP/1.1\r\nHost: localhost\r\n\r\n":utf8>>,
          2,
          2000,
        )
      server.stop(handle)
      body
    }
    Error(_start_error) -> Error("server did not start")
  }
}

@external(erlang, "streaming_api_sse_ffi", "free_port")
fn free_port() -> Int

@external(erlang, "streaming_api_sse_ffi", "read_events")
fn read_events(
  port: Int,
  request: BitArray,
  event_count: Int,
  timeout: Int,
) -> Result(String, String)
