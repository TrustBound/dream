//// Tests for the snippets in docs/guides/streaming.md and
//// docs/guides/streaming-quick-reference.md.
////
//// Each snippet in test/snippets/streaming_guide_*.gleam and
//// test/snippets/streaming_quick_*.gleam is shown, character for character,
//// in one of those guides. If a snippet breaks, these tests fail.

import dream/dream
import dream/http/request.{type Method, type Request, Get, Post, Put}
import dream/http/response.{type Response, Stream}
import dream/router.{type Router, route, router}
import dream/servers/mist/server
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}
import fixtures/request as test_request
import gleam/bit_array
import gleam/dynamic.{type Dynamic}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/string
import gleam/yielder
import simplifile
import snippets/streaming_guide_chunks
import snippets/streaming_guide_csv_export.{Product, Services as ProductServices}
import snippets/streaming_guide_download
import snippets/streaming_guide_file_download.{Services as FileServices}
import snippets/streaming_guide_ingress
import snippets/streaming_guide_middleware
import snippets/streaming_guide_patterns.{Services as UserServices, User}
import snippets/streaming_guide_pitfalls
import snippets/streaming_guide_saving.{Services as SavingServices}
import snippets/streaming_guide_sse
import snippets/streaming_guide_types
import snippets/streaming_guide_unit_test
import snippets/streaming_guide_upload_checks.{Services as ImageServices}
import snippets/streaming_quick_csv.{
  Product as QuickProduct, Services as QuickProductServices,
}
import snippets/streaming_quick_files.{Services as QuickFileServices}
import snippets/streaming_quick_middleware
import snippets/streaming_quick_patterns.{
  Services as QuickUserServices, User as QuickUser,
}
import snippets/streaming_quick_server
import snippets/streaming_quick_sse.{Services as QuickEventServices}
import snippets/streaming_quick_unit_test
import snippets/streaming_quick_upload

const scratch_directory = "build/streaming_snippets"

const png_header = <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A>>

pub fn tests() -> UnitTest {
  describe("streaming snippets", [
    guide_egress_tests(),
    guide_ingress_tests(),
    guide_saving_tests(),
    guide_middleware_tests(),
    guide_sse_tests(),
    guide_chunk_tests(),
    guide_upload_check_tests(),
    guide_pattern_tests(),
    guide_pitfall_tests(),
    guide_type_tests(),
    streaming_guide_unit_test.tests(),
    quick_tests(),
    quick_file_tests(),
    quick_sse_tests(),
    streaming_quick_unit_test.tests(),
  ])
}

// ============================================================================
// docs/guides/streaming.md
// ============================================================================

fn guide_egress_tests() -> UnitTest {
  describe("guide egress", [
    it("download streams 1000 chunks", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/download")

      // Act
      let response = streaming_guide_download.download(request, Nil, Nil)

      // Assert
      response
      |> stream_chunks
      |> list.length
      |> should()
      |> equal(1000)
      |> or_fail_with("download should stream 1000 chunks")
    }),
    it("download starts with Line 1 and Line 2", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/download")

      // Act
      let response = streaming_guide_download.download(request, Nil, Nil)

      // Assert
      response
      |> stream_chunks
      |> list.take(2)
      |> should()
      |> equal([<<"Line 1\n":utf8>>, <<"Line 2\n":utf8>>])
      |> or_fail_with("download should start with Line 1 and Line 2")
    }),
    it("export_products streams a CSV header and one row per product", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/products.csv")
      let services =
        ProductServices(list_products: fn() {
          Ok([
            Product(id: 1, name: "Lamp", price: 19.5, stock: 3),
            Product(id: 2, name: "Desk", price: 120.0, stock: 1),
          ])
        })

      // Act
      let response =
        streaming_guide_csv_export.export_products(request, Nil, services)

      // Assert
      response
      |> stream_text
      |> should()
      |> equal("id,name,price,stock\n1,Lamp,19.5,3\n2,Desk,120.0,1\n")
      |> or_fail_with("export_products should stream the CSV")
    }),
    it("export_products returns 500 when the products do not load", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/products.csv")
      let services =
        ProductServices(list_products: fn() { Error("connection lost") })

      // Act
      let response =
        streaming_guide_csv_export.export_products(request, Nil, services)

      // Assert
      response.status
      |> should()
      |> equal(500)
      |> or_fail_with("export_products should return 500")
    }),
    it("download_file sends a 70000 byte file in 64 KB chunks", fn() {
      // Arrange
      let path = scratch_path("download_file.bin")
      let _ = simplifile.write_bits(path, create_bytes(70_000))
      let request = test_request.create_request(Get, "/file")

      // Act
      let response =
        streaming_guide_file_download.download_file(
          request,
          Nil,
          FileServices(file_path: path),
        )

      // Assert
      response
      |> stream_chunks
      |> list.map(bit_array.byte_size)
      |> should()
      |> equal([65_536, 4464])
      |> or_fail_with("download_file should send a 64 KB chunk and the rest")
    }),
    it("download_file returns 404 when the file is missing", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/file")
      let services = FileServices(file_path: scratch_path("missing.bin"))

      // Act
      let response =
        streaming_guide_file_download.download_file(request, Nil, services)

      // Assert
      response.status
      |> should()
      |> equal(404)
      |> or_fail_with("download_file should return 404")
    }),
  ])
}

fn guide_ingress_tests() -> UnitTest {
  describe("guide ingress", [
    it("POST /upload_stream counts the streamed bytes", fn() {
      // Arrange
      let request =
        test_request.create_streaming_request_from_strings(
          Post,
          "/upload_stream",
          ["hello", " world"],
        )

      // Act
      let response =
        dream.route_request(
          streaming_guide_ingress.create_router(),
          request,
          Nil,
          Nil,
        )

      // Assert
      response
      |> text_body
      |> should()
      |> equal("Uploaded 11 bytes successfully")
      |> or_fail_with("upload_stream should count 11 bytes")
    }),
    it("POST /upload counts the buffered bytes", fn() {
      // Arrange
      let request =
        test_request.create_request_with_body(Post, "/upload", "hello")

      // Act
      let response =
        dream.route_request(
          streaming_guide_ingress.create_router(),
          request,
          Nil,
          Nil,
        )

      // Assert
      response
      |> text_body
      |> should()
      |> equal("Uploaded 5 bytes successfully")
      |> or_fail_with("upload_buffered should count 5 bytes")
    }),
    it("upload_stream returns 400 without a request stream", fn() {
      // Arrange
      let request = test_request.create_request(Post, "/upload_stream")

      // Act
      let response = streaming_guide_ingress.upload_stream(request, Nil, Nil)

      // Assert
      response.status
      |> should()
      |> equal(400)
      |> or_fail_with("upload_stream should return 400")
    }),
    it("the buffered upload router does not stream POST /upload", fn() {
      // Arrange
      let app_router = streaming_guide_ingress.create_buffered_upload_router()

      // Act
      let streaming = find_streaming_flag(app_router, Post, "/upload")

      // Assert
      streaming
      |> should()
      |> equal(Some(False))
      |> or_fail_with("route should not stream")
    }),
    it("the streaming upload router streams POST /upload", fn() {
      // Arrange
      let app_router = streaming_guide_ingress.create_streaming_upload_router()

      // Act
      let streaming = find_streaming_flag(app_router, Post, "/upload")

      // Assert
      streaming
      |> should()
      |> equal(Some(True))
      |> or_fail_with("stream_route should stream")
    }),
    it("the file router streams PUT /files/report.csv", fn() {
      // Arrange
      let app_router = streaming_guide_ingress.create_file_router()

      // Act
      let streaming = find_streaming_flag(app_router, Put, "/files/report.csv")

      // Assert
      streaming
      |> should()
      |> equal(Some(True))
      |> or_fail_with("stream_route should stream a PUT route")
    }),
  ])
}

fn guide_saving_tests() -> UnitTest {
  describe("guide saving", [
    it("save_upload writes the stream to the file", fn() {
      // Arrange
      let path = scratch_path("save_upload.bin")
      let _ = simplifile.delete(path)
      let request =
        test_request.create_streaming_request_from_strings(Post, "/upload", [
          "hello", " world",
        ])
      let services = SavingServices(upload_path: path, max_upload_bytes: 100)

      // Act
      let _response = streaming_guide_saving.save_upload(request, Nil, services)

      // Assert
      simplifile.read(path)
      |> should()
      |> equal(Ok("hello world"))
      |> or_fail_with("save_upload should write 'hello world'")
    }),
    it("save_upload returns 200 when it saves the file", fn() {
      // Arrange
      let path = scratch_path("save_upload_status.bin")
      let _ = simplifile.delete(path)
      let request =
        test_request.create_streaming_request_from_strings(Post, "/upload", [
          "hello",
        ])
      let services = SavingServices(upload_path: path, max_upload_bytes: 100)

      // Act
      let response = streaming_guide_saving.save_upload(request, Nil, services)

      // Assert
      response.status
      |> should()
      |> equal(200)
      |> or_fail_with("save_upload should return 200")
    }),
    it("save_upload_with_limit deletes a partial upload over the limit", fn() {
      // Arrange
      let path = scratch_path("save_upload_with_limit.bin")
      let _ = simplifile.delete(path)
      let request =
        test_request.create_streaming_request_from_strings(Post, "/upload", [
          "hello", " world",
        ])
      let services = SavingServices(upload_path: path, max_upload_bytes: 8)

      // Act
      let _response =
        streaming_guide_saving.save_upload_with_limit(request, Nil, services)

      // Assert
      simplifile.is_file(path)
      |> should()
      |> equal(Ok(False))
      |> or_fail_with("the partial upload should be deleted")
    }),
    it("save_upload_with_limit returns 400 over the limit", fn() {
      // Arrange
      let path = scratch_path("save_upload_with_limit_status.bin")
      let _ = simplifile.delete(path)
      let request =
        test_request.create_streaming_request_from_strings(Post, "/upload", [
          "hello", " world",
        ])
      let services = SavingServices(upload_path: path, max_upload_bytes: 8)

      // Act
      let response =
        streaming_guide_saving.save_upload_with_limit(request, Nil, services)

      // Assert
      response.status
      |> should()
      |> equal(400)
      |> or_fail_with("save_upload_with_limit should return 400")
    }),
    it("save_upload_with_limit returns 201 under the limit", fn() {
      // Arrange
      let path = scratch_path("save_upload_with_limit_created.bin")
      let _ = simplifile.delete(path)
      let request =
        test_request.create_streaming_request_from_strings(Post, "/upload", [
          "hello",
        ])
      let services = SavingServices(upload_path: path, max_upload_bytes: 8)

      // Act
      let response =
        streaming_guide_saving.save_upload_with_limit(request, Nil, services)

      // Assert
      response.status
      |> should()
      |> equal(201)
      |> or_fail_with("save_upload_with_limit should return 201")
    }),
  ])
}

fn guide_middleware_tests() -> UnitTest {
  describe("guide middleware", [
    it("POST /transform uppercases input and replaces spaces in output", fn() {
      // Arrange
      let request =
        test_request.create_streaming_request_from_strings(Post, "/transform", [
          "hello world",
        ])

      // Act
      let response =
        dream.route_request(
          streaming_guide_middleware.create_router(),
          request,
          Nil,
          Nil,
        )

      // Assert
      response
      |> stream_text
      |> should()
      |> equal("HELLO_WORLD")
      |> or_fail_with("POST /transform should return HELLO_WORLD")
    }),
    it("POST /transform keeps a character split across two chunks", fn() {
      // Arrange
      let request =
        test_request.create_streaming_request(
          Post,
          "/transform",
          yielder.from_list([<<"caf":utf8, 0xC3>>, <<0xA9, " ok":utf8>>]),
        )

      // Act
      let response =
        dream.route_request(
          streaming_guide_middleware.create_router(),
          request,
          Nil,
          Nil,
        )

      // Assert
      response
      |> stream_text
      |> should()
      |> equal("CAFé_OK")
      |> or_fail_with("POST /transform should return CAFé_OK")
    }),
  ])
}

fn guide_sse_tests() -> UnitTest {
  describe("guide sse", [
    it("handle_events sends one ping event", fn() {
      // Arrange
      let port = 19_986
      let app_router =
        router()
        |> route(
          method: Get,
          path: "/events",
          controller: streaming_guide_sse.handle_events,
          middleware: [],
        )
      let started =
        server.new()
        |> server.router(app_router)
        |> server.bind("127.0.0.1")
        |> server.listen_with_handle(port)

      // Act
      let received = request_raw(started, port, "/events")

      // Assert
      received
      |> should()
      |> equal(Ok("data: ping\n\n"))
      |> or_fail_with("handle_events should send one ping event")
    }),
    it("long_running_task sends progress events up to 100", fn() {
      // Arrange
      let port = 19_987
      let app_router =
        router()
        |> route(
          method: Get,
          path: "/progress",
          controller: streaming_guide_sse.long_running_task,
          middleware: [],
        )
      let started =
        server.new()
        |> server.router(app_router)
        |> server.bind("127.0.0.1")
        |> server.listen_with_handle(port)

      // Act
      let received = request_raw(started, port, "/progress")

      // Assert
      received
      |> should()
      |> equal(Ok(progress_events))
      |> or_fail_with("long_running_task should send 5 progress events")
    }),
  ])
}

fn guide_chunk_tests() -> UnitTest {
  describe("guide chunks", [
    it("create_line_stream makes 1000 chunks", fn() {
      // Arrange
      let stream = streaming_guide_chunks.create_line_stream()

      // Act
      let chunk_count = yielder.length(stream)

      // Assert
      chunk_count
      |> should()
      |> equal(1000)
      |> or_fail_with("create_line_stream should make 1000 chunks")
    }),
    it("create_batched_line_stream makes 10 chunks", fn() {
      // Arrange
      let stream = streaming_guide_chunks.create_batched_line_stream()

      // Act
      let chunk_count = yielder.length(stream)

      // Assert
      chunk_count
      |> should()
      |> equal(10)
      |> or_fail_with("create_batched_line_stream should make 10 chunks")
    }),
    it("create_batched_line_stream keeps every byte", fn() {
      // Arrange
      let stream = streaming_guide_chunks.create_batched_line_stream()

      // Act
      let byte_count =
        stream
        |> yielder.to_list
        |> bit_array.concat
        |> bit_array.byte_size

      // Assert
      byte_count
      |> should()
      |> equal(3893)
      |> or_fail_with("the batched stream should hold 3893 bytes")
    }),
    it("create_tiny_chunks makes 1000 chunks", fn() {
      // Arrange
      let data = <<"x":utf8>>

      // Act
      let chunk_count =
        streaming_guide_chunks.create_tiny_chunks(data) |> yielder.length

      // Assert
      chunk_count
      |> should()
      |> equal(1000)
      |> or_fail_with("create_tiny_chunks should make 1000 chunks")
    }),
    it("group_chunks puts 64 chunks into each chunk", fn() {
      // Arrange
      let stream = yielder.repeat(<<"x":utf8>>) |> yielder.take(130)

      // Act
      let sizes =
        streaming_guide_chunks.group_chunks(stream)
        |> yielder.map(bit_array.byte_size)
        |> yielder.to_list

      // Assert
      sizes
      |> should()
      |> equal([64, 64, 2])
      |> or_fail_with("group_chunks should make chunks of 64, 64 and 2")
    }),
    it("create_row_chunks makes one chunk per row", fn() {
      // Arrange
      let rows = ["1,Ada\n", "2,Bo\n"]

      // Act
      let chunks =
        streaming_guide_chunks.create_row_chunks(rows) |> yielder.to_list

      // Assert
      chunks
      |> should()
      |> equal([<<"1,Ada\n":utf8>>, <<"2,Bo\n":utf8>>])
      |> or_fail_with("create_row_chunks should make one chunk per row")
    }),
  ])
}

fn guide_upload_check_tests() -> UnitTest {
  describe("guide upload checks", [
    it("upload_stream counts the processed bytes", fn() {
      // Arrange
      let request =
        test_request.create_streaming_request_from_strings(Post, "/upload", [
          "hello", " world",
        ])

      // Act
      let response =
        streaming_guide_upload_checks.upload_stream(request, Nil, Nil)

      // Assert
      response
      |> text_body
      |> should()
      |> equal("Processed 11 bytes")
      |> or_fail_with("upload_stream should process 11 bytes")
    }),
    it("upload_stream rejects an upload over 1000000 bytes", fn() {
      // Arrange
      let request =
        test_request.create_streaming_request(
          Post,
          "/upload",
          yielder.from_list([create_bytes(600_000), create_bytes(600_000)]),
        )

      // Act
      let response =
        streaming_guide_upload_checks.upload_stream(request, Nil, Nil)

      // Assert
      response
      |> text_body
      |> should()
      |> equal("Upload is larger than 1000000 bytes")
      |> or_fail_with("upload_stream should reject the upload")
    }),
    it("upload_image saves a PNG and returns its path", fn() {
      // Arrange
      let path = scratch_path("guide_image.png")
      let request =
        test_request.create_streaming_request(
          Post,
          "/images",
          yielder.from_list([png_header, <<"rest":utf8>>]),
        )

      // Act
      let response =
        streaming_guide_upload_checks.upload_image(
          request,
          Nil,
          ImageServices(upload_path: path),
        )

      // Assert
      response
      |> text_body
      |> should()
      |> equal("{\"path\":\"build/streaming_snippets/guide_image.png\"}")
      |> or_fail_with("upload_image should return the saved path")
    }),
    it("upload_image writes every chunk to the file", fn() {
      // Arrange
      let path = scratch_path("guide_image_bytes.png")
      let request =
        test_request.create_streaming_request(
          Post,
          "/images",
          yielder.from_list([png_header, <<"rest":utf8>>]),
        )

      // Act
      let _response =
        streaming_guide_upload_checks.upload_image(
          request,
          Nil,
          ImageServices(upload_path: path),
        )

      // Assert
      simplifile.read_bits(path)
      |> should()
      |> equal(Ok(<<png_header:bits, "rest":utf8>>))
      |> or_fail_with("upload_image should write the PNG header and the rest")
    }),
    it("upload_image returns 422 for a file that is not an image", fn() {
      // Arrange
      let request =
        test_request.create_streaming_request_from_strings(Post, "/images", [
          "plain text",
        ])

      // Act
      let response =
        streaming_guide_upload_checks.upload_image(
          request,
          Nil,
          ImageServices(upload_path: scratch_path("guide_not_image.txt")),
        )

      // Assert
      response.status
      |> should()
      |> equal(422)
      |> or_fail_with("upload_image should return 422")
    }),
  ])
}

fn guide_pattern_tests() -> UnitTest {
  describe("guide patterns", [
    it("export_users_csv streams a CSV header and one row per user", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/users.csv")
      let services = UserServices(list_users: fn() { Ok(guide_users()) })

      // Act
      let response =
        streaming_guide_patterns.export_users_csv(request, Nil, services)

      // Assert
      response
      |> stream_text
      |> should()
      |> equal(users_csv)
      |> or_fail_with("export_users_csv should stream the CSV")
    }),
    it("export_users_buffered returns the whole CSV as text", fn() {
      // Arrange
      let users = guide_users()

      // Act
      let response = streaming_guide_patterns.export_users_buffered(users)

      // Assert
      response
      |> text_body
      |> should()
      |> equal(users_csv)
      |> or_fail_with("export_users_buffered should return the CSV")
    }),
    it("export_users_streamed streams the CSV", fn() {
      // Arrange
      let users = yielder.from_list(guide_users())

      // Act
      let response = streaming_guide_patterns.export_users_streamed(users)

      // Assert
      response
      |> stream_text
      |> should()
      |> equal(users_csv)
      |> or_fail_with("export_users_streamed should stream the CSV")
    }),
  ])
}

fn guide_pitfall_tests() -> UnitTest {
  describe("guide pitfalls", [
    it("download_with_line_count counts the lines, then streams them", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/download")

      // Act
      let response =
        streaming_guide_pitfalls.download_with_line_count(request, Nil, Nil)

      // Assert
      response
      |> stream_chunks
      |> list.take(2)
      |> should()
      |> equal([<<"Lines: 100\n":utf8>>, <<"Line 1\n":utf8>>])
      |> or_fail_with("the body should start with the count and Line 1")
    }),
    it("send_buffered sends the same bytes as send_lazy", fn() {
      // Arrange
      let stream = yielder.from_list([<<"a":utf8>>, <<"b":utf8>>])

      // Act
      let buffered = streaming_guide_pitfalls.send_buffered(stream)

      // Assert
      stream_text(buffered)
      |> should()
      |> equal(stream_text(streaming_guide_pitfalls.send_lazy(stream)))
      |> or_fail_with("both should send 'ab'")
    }),
    it("send_lazy sends the stream", fn() {
      // Arrange
      let stream = yielder.from_list([<<"a":utf8>>, <<"b":utf8>>])

      // Act
      let response = streaming_guide_pitfalls.send_lazy(stream)

      // Assert
      response
      |> stream_text
      |> should()
      |> equal("ab")
      |> or_fail_with("send_lazy should send 'ab'")
    }),
    it("upload_without_check answers 200 when the stream is missing", fn() {
      // Arrange
      let request = test_request.create_request(Post, "/upload")

      // Act
      let response =
        streaming_guide_pitfalls.upload_without_check(request, Nil, Nil)

      // Assert
      response
      |> text_body
      |> should()
      |> equal("Saved 0 bytes")
      |> or_fail_with("the bad controller should hide the missing stream")
    }),
    it("upload_with_check returns 400 when the stream is missing", fn() {
      // Arrange
      let request = test_request.create_request(Post, "/upload")

      // Act
      let response =
        streaming_guide_pitfalls.upload_with_check(request, Nil, Nil)

      // Assert
      response.status
      |> should()
      |> equal(400)
      |> or_fail_with("upload_with_check should return 400")
    }),
    it("upload_with_check saves a streamed upload", fn() {
      // Arrange
      let request =
        test_request.create_streaming_request_from_strings(Post, "/upload", [
          "hello",
        ])

      // Act
      let response =
        streaming_guide_pitfalls.upload_with_check(request, Nil, Nil)

      // Assert
      response
      |> text_body
      |> should()
      |> equal("Saved 5 bytes")
      |> or_fail_with("upload_with_check should save 5 bytes")
    }),
  ])
}

fn guide_type_tests() -> UnitTest {
  describe("guide types", [
    it("create_text_body makes a Text body", fn() {
      // Arrange
      let body = streaming_guide_types.create_text_body()

      // Act
      let description = streaming_guide_types.describe_body(body)

      // Assert
      description
      |> should()
      |> equal("Text: Hello, World!")
      |> or_fail_with("create_text_body should make Text(\"Hello, World!\")")
    }),
    it("create_bytes_body makes a Bytes body", fn() {
      // Arrange
      let body = streaming_guide_types.create_bytes_body(<<1, 2, 3>>)

      // Act
      let description = streaming_guide_types.describe_body(body)

      // Assert
      description
      |> should()
      |> equal("Bytes: 3")
      |> or_fail_with("create_bytes_body should make a 3 byte Bytes body")
    }),
    it("create_stream_body makes a Stream body", fn() {
      // Arrange
      let body =
        streaming_guide_types.create_stream_body(yielder.from_list([<<1>>]))

      // Act
      let description = streaming_guide_types.describe_body(body)

      // Assert
      description
      |> should()
      |> equal("Stream")
      |> or_fail_with("create_stream_body should make a Stream body")
    }),
    it("create_csv_download sets text/csv", fn() {
      // Arrange
      let rows = yielder.from_list([<<"id\n":utf8>>])

      // Act
      let response = streaming_guide_types.create_csv_download(rows)

      // Assert
      response.content_type
      |> should()
      |> equal(Some("text/csv"))
      |> or_fail_with("create_csv_download should set text/csv")
    }),
    it("create_streaming_request replaces the body with the stream", fn() {
      // Arrange
      let request =
        test_request.create_request_with_body(Post, "/upload", "buffered")

      // Act
      let streaming_request =
        streaming_guide_types.create_streaming_request(
          request,
          yielder.from_list([<<"chunk":utf8>>]),
        )

      // Assert
      request_stream_text(streaming_request)
      |> should()
      |> equal(Some("chunk"))
      |> or_fail_with("the streaming request should hold the chunks")
    }),
  ])
}

// ============================================================================
// docs/guides/streaming-quick-reference.md
// ============================================================================

fn quick_tests() -> UnitTest {
  describe("quick reference", [
    it("POST /upload counts the uploaded bytes", fn() {
      // Arrange
      let request =
        test_request.create_streaming_request_from_strings(Post, "/upload", [
          "hello", " world",
        ])

      // Act
      let response =
        dream.route_request(
          streaming_quick_upload.create_router(),
          request,
          Nil,
          Nil,
        )

      // Assert
      response
      |> text_body
      |> should()
      |> equal("Uploaded 11 bytes")
      |> or_fail_with("upload_file should count 11 bytes")
    }),
    it("upload_file returns 400 without a request stream", fn() {
      // Arrange
      let request = test_request.create_request(Post, "/upload")

      // Act
      let response = streaming_quick_upload.upload_file(request, Nil, Nil)

      // Assert
      response.status
      |> should()
      |> equal(400)
      |> or_fail_with("upload_file should return 400")
    }),
    it("export_csv streams a CSV header and one row per product", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/products.csv")
      let services =
        QuickProductServices(list_products: fn() {
          Ok([QuickProduct(id: 1, name: "Lamp", price: 19.5)])
        })

      // Act
      let response = streaming_quick_csv.export_csv(request, Nil, services)

      // Assert
      response
      |> stream_text
      |> should()
      |> equal("id,name,price\n1,Lamp,19.5\n")
      |> or_fail_with("export_csv should stream the CSV")
    }),
    it("export_csv returns 500 when the products do not load", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/products.csv")
      let services =
        QuickProductServices(list_products: fn() { Error("connection lost") })

      // Act
      let response = streaming_quick_csv.export_csv(request, Nil, services)

      // Assert
      response.status
      |> should()
      |> equal(500)
      |> or_fail_with("export_csv should return 500")
    }),
    it("uppercase_middleware uppercases the request stream", fn() {
      // Arrange
      let request =
        test_request.create_streaming_request_from_strings(Post, "/echo", [
          "hello world",
        ])

      // Act
      let response =
        streaming_quick_middleware.uppercase_middleware(
          request,
          Nil,
          Nil,
          echo_request_stream,
        )

      // Assert
      response
      |> stream_text
      |> should()
      |> equal("HELLO WORLD")
      |> or_fail_with("uppercase_middleware should uppercase the stream")
    }),
    it("line_endings_middleware converts LF to CRLF in the response", fn() {
      // Arrange
      let request =
        test_request.create_streaming_request_from_strings(Post, "/echo", [
          "a\nb\n",
        ])

      // Act
      let response =
        streaming_quick_middleware.line_endings_middleware(
          request,
          Nil,
          Nil,
          echo_request_stream,
        )

      // Assert
      response
      |> stream_text
      |> should()
      |> equal("a\r\nb\r\n")
      |> or_fail_with("line_endings_middleware should write CRLF")
    }),
    it("uppercase_middleware keeps a character split across two chunks", fn() {
      // Arrange
      let request =
        test_request.create_streaming_request(
          Post,
          "/echo",
          yielder.from_list([<<"caf":utf8, 0xC3>>, <<0xA9, " ok":utf8>>]),
        )

      // Act
      let response =
        streaming_quick_middleware.uppercase_middleware(
          request,
          Nil,
          Nil,
          echo_request_stream,
        )

      // Assert
      response
      |> stream_text
      |> should()
      |> equal("CAFé OK")
      |> or_fail_with("uppercase_middleware should return CAFé OK")
    }),
    it(
      "line_endings_middleware keeps a character split across two chunks",
      fn() {
        // Arrange
        let request =
          test_request.create_streaming_request(
            Post,
            "/echo",
            yielder.from_list([<<"a":utf8, 0xC3>>, <<0xA9, "\n":utf8>>]),
          )

        // Act
        let response =
          streaming_quick_middleware.line_endings_middleware(
            request,
            Nil,
            Nil,
            echo_request_stream,
          )

        // Assert
        response
        |> stream_text
        |> should()
        |> equal("aé\r\n")
        |> or_fail_with("line_endings_middleware should return aé and CRLF")
      },
    ),
    it("proxy streams three chunks", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/proxy")

      // Act
      let response = streaming_quick_patterns.proxy(request, Nil, Nil)

      // Assert
      response
      |> stream_text
      |> should()
      |> equal("Chunk 1\nChunk 2\nChunk 3\n")
      |> or_fail_with("proxy should stream three chunks")
    }),
    it("export_users streams a CSV header and one row per user", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/users.csv")

      // Act
      let response =
        streaming_quick_patterns.export_users(request, Nil, quick_services())

      // Assert
      response
      |> stream_text
      |> should()
      |> equal(users_csv)
      |> or_fail_with("export_users should stream the CSV")
    }),
    it("get_users streams CSV for format=csv", fn() {
      // Arrange
      let request =
        test_request.create_request_with_query(Get, "/users", "format=csv")

      // Act
      let response =
        streaming_quick_patterns.get_users(request, Nil, quick_services())

      // Assert
      response
      |> stream_text
      |> should()
      |> equal(users_csv)
      |> or_fail_with("get_users should stream CSV")
    }),
    it("get_users returns JSON for format=json", fn() {
      // Arrange
      let request =
        test_request.create_request_with_query(Get, "/users", "format=json")

      // Act
      let response =
        streaming_quick_patterns.get_users(request, Nil, quick_services())

      // Assert
      response
      |> text_body
      |> should()
      |> equal(
        "[{\"id\":1,\"name\":\"Ada\",\"email\":\"ada@example.com\"},"
        <> "{\"id\":2,\"name\":\"Bo\",\"email\":\"bo@example.com\"}]",
      )
      |> or_fail_with("get_users should return JSON")
    }),
    it("get_users returns 400 for another format", fn() {
      // Arrange
      let request =
        test_request.create_request_with_query(Get, "/users", "format=xml")

      // Act
      let response =
        streaming_quick_patterns.get_users(request, Nil, quick_services())

      // Assert
      response.status
      |> should()
      |> equal(400)
      |> or_fail_with("get_users should return 400")
    }),
    it("create_server sets a 100MB body limit", fn() {
      // Arrange
      let dream_server = streaming_quick_server.create_server()

      // Act
      let max_body_size = dream.get_max_body_size(dream_server)

      // Assert
      max_body_size
      |> should()
      |> equal(100_000_000)
      |> or_fail_with("create_server should set 100_000_000 bytes")
    }),
  ])
}

fn quick_file_tests() -> UnitTest {
  describe("quick reference files", [
    it("save_upload writes the stream to the file", fn() {
      // Arrange
      let path = scratch_path("quick_save_upload.bin")
      let request =
        test_request.create_streaming_request_from_strings(Post, "/upload", [
          "hello", " world",
        ])

      // Act
      let _response =
        streaming_quick_files.save_upload(
          request,
          Nil,
          QuickFileServices(upload_path: path),
        )

      // Assert
      simplifile.read(path)
      |> should()
      |> equal(Ok("hello world"))
      |> or_fail_with("save_upload should write 'hello world'")
    }),
    it("save_upload names the saved file", fn() {
      // Arrange
      let path = scratch_path("quick_save_upload_name.bin")
      let request =
        test_request.create_streaming_request_from_strings(Post, "/upload", [
          "hello",
        ])

      // Act
      let response =
        streaming_quick_files.save_upload(
          request,
          Nil,
          QuickFileServices(upload_path: path),
        )

      // Assert
      response
      |> text_body
      |> should()
      |> equal(
        "File saved: build/streaming_snippets/quick_save_upload_name.bin",
      )
      |> or_fail_with("save_upload should name the saved file")
    }),
    it("upload_image returns 201 for a PNG", fn() {
      // Arrange
      let request =
        test_request.create_streaming_request(
          Post,
          "/images",
          yielder.from_list([png_header, <<"rest":utf8>>]),
        )

      // Act
      let response =
        streaming_quick_files.upload_image(
          request,
          Nil,
          QuickFileServices(upload_path: scratch_path("quick_image.png")),
        )

      // Assert
      response.status
      |> should()
      |> equal(201)
      |> or_fail_with("upload_image should return 201")
    }),
    it("upload_image writes the first chunk and the rest", fn() {
      // Arrange
      let path = scratch_path("quick_image_bytes.png")
      let request =
        test_request.create_streaming_request(
          Post,
          "/images",
          yielder.from_list([png_header, <<"rest":utf8>>]),
        )

      // Act
      let _response =
        streaming_quick_files.upload_image(
          request,
          Nil,
          QuickFileServices(upload_path: path),
        )

      // Assert
      simplifile.read_bits(path)
      |> should()
      |> equal(Ok(<<png_header:bits, "rest":utf8>>))
      |> or_fail_with("upload_image should write the PNG header and the rest")
    }),
    it("upload_image returns 422 for a file that is not an image", fn() {
      // Arrange
      let request =
        test_request.create_streaming_request_from_strings(Post, "/images", [
          "plain text",
        ])

      // Act
      let response =
        streaming_quick_files.upload_image(
          request,
          Nil,
          QuickFileServices(upload_path: scratch_path("quick_not_image.txt")),
        )

      // Assert
      response.status
      |> should()
      |> equal(422)
      |> or_fail_with("upload_image should return 422")
    }),
    it("upload_image returns 400 for an empty upload", fn() {
      // Arrange
      let request =
        test_request.create_streaming_request(Post, "/images", yielder.empty())

      // Act
      let response =
        streaming_quick_files.upload_image(
          request,
          Nil,
          QuickFileServices(upload_path: scratch_path("quick_empty.png")),
        )

      // Assert
      response.status
      |> should()
      |> equal(400)
      |> or_fail_with("upload_image should return 400")
    }),
  ])
}

fn quick_sse_tests() -> UnitTest {
  describe("quick reference sse", [
    it("events sends one event per item in Services", fn() {
      // Arrange
      let port = 19_988
      let app_router =
        router()
        |> route(
          method: Get,
          path: "/events",
          controller: streaming_quick_sse.events,
          middleware: [],
        )
      let started =
        server.new()
        |> server.services(QuickEventServices(events: ["first", "second"]))
        |> server.router(app_router)
        |> server.bind("127.0.0.1")
        |> server.listen_with_handle(port)

      // Act
      let received = request_raw(started, port, "/events")

      // Assert
      received
      |> should()
      |> equal(Ok("data: first\n\ndata: second\n\n"))
      |> or_fail_with("events should send 'first' and 'second'")
    }),
    it("long_task sends progress events up to 100", fn() {
      // Arrange
      let port = 19_989
      let app_router =
        router()
        |> route(
          method: Get,
          path: "/progress",
          controller: streaming_quick_sse.long_task,
          middleware: [],
        )
      let started =
        server.new()
        |> server.router(app_router)
        |> server.bind("127.0.0.1")
        |> server.listen_with_handle(port)

      // Act
      let received = request_raw(started, port, "/progress")

      // Assert
      received
      |> should()
      |> equal(Ok(progress_events))
      |> or_fail_with("long_task should send 5 progress events")
    }),
  ])
}

// ============================================================================
// Test data and helpers
// ============================================================================

const users_csv = "id,name,email\n1,Ada,ada@example.com\n2,Bo,bo@example.com\n"

const progress_events = "data: {\"progress\": 0}\n\n"
  <> "data: {\"progress\": 25}\n\n"
  <> "data: {\"progress\": 50}\n\n"
  <> "data: {\"progress\": 75}\n\n"
  <> "data: {\"progress\": 100}\n\n"

fn guide_users() -> List(streaming_guide_patterns.User) {
  [
    User(id: 1, name: "Ada", email: "ada@example.com"),
    User(id: 2, name: "Bo", email: "bo@example.com"),
  ]
}

fn quick_services() -> streaming_quick_patterns.Services {
  QuickUserServices(list_users: fn() {
    Ok([
      QuickUser(id: 1, name: "Ada", email: "ada@example.com"),
      QuickUser(id: 2, name: "Bo", email: "bo@example.com"),
    ])
  })
}

fn scratch_path(name: String) -> String {
  let _ = simplifile.create_directory_all(scratch_directory)
  scratch_directory <> "/" <> name
}

fn create_bytes(size: Int) -> BitArray {
  <<0:size({ size * 8 })>>
}

fn stream_chunks(response: Response) -> List(BitArray) {
  case response.body {
    Stream(stream) -> yielder.to_list(stream)
    _other -> []
  }
}

fn stream_text(response: Response) -> String {
  response
  |> stream_chunks
  |> bit_array.concat
  |> bit_array.to_string
  |> option.from_result
  |> option.unwrap("")
}

fn text_body(response: Response) -> String {
  case response.body {
    response.Text(text) -> text
    _other -> ""
  }
}

fn request_stream_text(request: Request) -> Option(String) {
  case request.body {
    request.Stream(stream) ->
      stream
      |> yielder.to_list
      |> bit_array.concat
      |> bit_array.to_string
      |> option.from_result
    _other -> None
  }
}

fn echo_request_stream(
  request: Request,
  _context: Nil,
  _services: Nil,
) -> Response {
  case request.body {
    request.Stream(stream) ->
      response.stream_response(200, stream, "text/plain")
    _other -> response.text_response(400, "no stream")
  }
}

fn find_streaming_flag(
  app_router: Router(Nil, Nil),
  method: Method,
  path: String,
) -> Option(Bool) {
  router.find_route(app_router, test_request.create_request(method, path))
  |> option.map(fn(found) { { found.0 }.streaming })
}

/// Sends one raw HTTP/1.1 GET to a server that `started` reports, reads until
/// the server closes the socket or 1 second passes with no data, stops the
/// server and returns the bytes after the response headers.
fn request_raw(
  started: Result(server.ServerHandle, actor.StartError),
  port: Int,
  path: String,
) -> Result(String, String) {
  case started {
    Ok(handle) -> {
      let payload = "GET " <> path <> " HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n"
      let received =
        request_until_closed(port, bit_array.from_string(payload), 1000)
      server.stop(handle)
      received_body(received)
    }
    Error(_start_error) -> Error("server did not start")
  }
}

fn received_body(
  received: Result(BitArray, Dynamic),
) -> Result(String, String) {
  case received {
    Ok(bytes) -> split_body(bytes)
    Error(_reason) -> Error("request failed")
  }
}

fn split_body(bytes: BitArray) -> Result(String, String) {
  case bit_array.to_string(bytes) {
    Ok(text) -> after_headers(text)
    Error(Nil) -> Error("response is not UTF-8")
  }
}

fn after_headers(text: String) -> Result(String, String) {
  case string.split_once(text, "\r\n\r\n") {
    Ok(#(_headers, body)) -> Ok(body)
    Error(Nil) -> Error("no header end in: " <> text)
  }
}

@external(erlang, "raw_http_ffi", "request_until_closed")
fn request_until_closed(
  port: Int,
  payload: BitArray,
  timeout: Int,
) -> Result(BitArray, Dynamic)
