//// Tests for the snippets in the testing, controllers-and-models and
//// file-uploads guides.
////
//// Many testing guide snippets are test modules. These tests run them with
//// the dream_test runner and check the name and status of each result.

import dream/context.{type AppContext, AppContext}
import dream/http/error
import dream/http/request.{Get, Post}
import dream/http/response.{html_response, json_response}
import dream/http/validation.{ValidationError}
import dream_http_client/client
import dream_http_client/recorder
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/runner
import dream_test/types.{
  type Status, AssertionFailure, CustomMatcherFailure, MatchFailed, MatchOk,
  Passed,
}
import dream_test/unit.{type UnitTest, describe, it}
import fixtures/request as test_request
import gleam/bit_array
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import simplifile
import snippets/controllers_guide_controller
import snippets/controllers_guide_multi_format
import snippets/controllers_guide_response_helpers
import snippets/controllers_guide_services.{
  type Services, Connection, Database, Services,
}
import snippets/controllers_guide_task.{Task}
import snippets/controllers_guide_task_view
import snippets/file_uploads_guide_download
import snippets/file_uploads_guide_file_type
import snippets/file_uploads_guide_image
import snippets/file_uploads_guide_multiple
import snippets/file_uploads_guide_s3
import snippets/file_uploads_guide_upload
import snippets/file_uploads_guide_validation
import snippets/testing_guide_auth_middleware_test
import snippets/testing_guide_before_all
import snippets/testing_guide_before_each
import snippets/testing_guide_examples
import snippets/testing_guide_extract_user_name
import snippets/testing_guide_fixture_usage
import snippets/testing_guide_integration
import snippets/testing_guide_matchers
import snippets/testing_guide_quick_start
import snippets/testing_guide_request_fixture
import snippets/testing_guide_test_module
import snippets/testing_guide_user
import snippets/testing_guide_user_test
import snippets/testing_guide_users_controller_test

pub fn tests() -> UnitTest {
  describe("guide snippets", [
    testing_guide_tests(),
    controllers_guide_tests(),
    file_uploads_guide_tests(),
  ])
}

fn testing_guide_tests() -> UnitTest {
  describe("testing guide", [
    it("quick start test passes", fn() {
      // Arrange
      let snippet_tests = testing_guide_quick_start.tests()

      // Act
      let results = run_unit_tests(snippet_tests)

      // Assert
      results
      |> should()
      |> equal([#("creates user with valid data", Passed)])
      |> or_fail_with("Quick start test should pass")
    }),
    it("entry point exits with status 0 when its tests pass", fn() {
      // Arrange
      let module = "snippets@testing_guide_entry_point"

      // Act
      let exit_status = run_main_in_new_vm(module)

      // Assert
      exit_status
      |> should()
      |> equal(0)
      |> or_fail_with("Entry point should exit with status 0")
    }),
    it("test module pattern test passes", fn() {
      // Arrange
      let snippet_tests = testing_guide_test_module.tests()

      // Act
      let results = run_unit_tests(snippet_tests)

      // Assert
      results
      |> should()
      |> equal([#("joins lowercase words with dashes", Passed)])
      |> or_fail_with("Test module pattern test should pass")
    }),
    it("basic matcher tests pass", fn() {
      // Arrange
      let snippet_tests = testing_guide_matchers.tests()

      // Act
      let results = run_unit_tests(snippet_tests)

      // Assert
      results
      |> should()
      |> equal([
        #("be_empty", Passed),
        #("be_error", Passed),
        #("be_false", Passed),
        #("be_none", Passed),
        #("be_ok", Passed),
        #("be_some", Passed),
        #("be_true", Passed),
        #("contain", Passed),
        #("contain_string", Passed),
        #("equal", Passed),
      ])
      |> or_fail_with("Basic matcher tests should pass")
    }),
    it("chaining tests pass", fn() {
      // Arrange
      let snippet_tests = testing_guide_examples.chaining_tests()

      // Act
      let results = run_unit_tests(snippet_tests)

      // Assert
      results
      |> should()
      |> equal([#("accepts a valid email", Passed), #("finds user 1", Passed)])
      |> or_fail_with("Chaining tests should pass")
    }),
    it("custom matcher usage test passes", fn() {
      // Arrange
      let snippet_tests = testing_guide_examples.custom_matcher_tests()

      // Act
      let results = run_unit_tests(snippet_tests)

      // Assert
      results
      |> should()
      |> equal([#("reads the name from a valid user", Passed)])
      |> or_fail_with("Custom matcher usage test should pass")
    }),
    it("custom matcher fails on a validation error", fn() {
      // Arrange
      let validation_result =
        MatchOk(Error(ValidationError("bad", None, None, None)))

      // Act
      let result =
        testing_guide_extract_user_name.extract_user_name(
          validation_result,
          fn(user) { user.name },
        )

      // Assert
      result
      |> should()
      |> equal(
        MatchFailed(AssertionFailure(
          operator: "extract_user_name",
          message: "Expected Ok but got validation error",
          payload: Some(CustomMatcherFailure(
            actual: "Error(...)",
            description: "Validation failed",
          )),
        )),
      )
      |> or_fail_with("Custom matcher should fail")
    }),
    it("request fixture sets the body", fn() {
      // Arrange
      let body = "{\"name\":\"Alice\"}"

      // Act
      let request =
        testing_guide_request_fixture.create_request_with_body(
          Post,
          "/users",
          body,
        )

      // Assert
      request.body
      |> should()
      |> equal(body)
      |> or_fail_with("Fixture should set the body")
    }),
    it("fixture usage test passes", fn() {
      // Arrange
      let snippet_tests = testing_guide_fixture_usage.tests()

      // Act
      let results = run_unit_tests(snippet_tests)

      // Assert
      results
      |> should()
      |> equal([#("creates POST request with body", Passed)])
      |> or_fail_with("Fixture usage test should pass")
    }),
    it("before_each tests pass", fn() {
      // Arrange
      let snippet_tests = testing_guide_before_each.tests()

      // Act
      let results = run_unit_tests(snippet_tests)

      // Assert
      results
      |> should()
      |> equal([#("creates record", Passed), #("updates record", Passed)])
      |> or_fail_with("before_each tests should pass")
    }),
    it("before_all tests pass with run_suite", fn() {
      // Arrange
      let snippet_tests = testing_guide_before_all.tests()

      // Act
      let results = run_unit_suite(snippet_tests)

      // Assert
      results
      |> should()
      |> equal([
        #("responds to GET /", Passed),
        #("responds to GET /users", Passed),
      ])
      |> or_fail_with("before_all tests should pass")
    }),
    it("controller test passes", fn() {
      // Arrange
      let snippet_tests = testing_guide_users_controller_test.tests()

      // Act
      let results = run_unit_tests(snippet_tests)

      // Assert
      results
      |> should()
      |> equal([#("returns 200 for valid request", Passed)])
      |> or_fail_with("Controller test should pass")
    }),
    it("middleware tests pass", fn() {
      // Arrange
      let snippet_tests = testing_guide_auth_middleware_test.tests()

      // Act
      let results = run_unit_tests(snippet_tests)

      // Assert
      results
      |> should()
      |> equal([
        #("calls next with valid token", Passed),
        #("returns 401 without token", Passed),
      ])
      |> or_fail_with("Middleware tests should pass")
    }),
    it("model tests pass", fn() {
      // Arrange
      let snippet_tests = testing_guide_user_test.tests()

      // Act
      let results = run_unit_tests(snippet_tests)

      // Assert
      results
      |> should()
      |> equal([
        #("accepts valid email", Passed),
        #("rejects empty email", Passed),
      ])
      |> or_fail_with("Model tests should pass")
    }),
    it("integration test passes", fn() {
      // Arrange
      let snippet_tests = testing_guide_integration.tests()

      // Act
      let results = run_unit_tests(snippet_tests)

      // Assert
      results
      |> should()
      |> equal([#("saves user to disk", Passed)])
      |> or_fail_with("Integration test should pass")
    }),
    it("black box tests pass", fn() {
      // Arrange
      let snippet_tests = testing_guide_examples.black_box_tests()

      // Act
      let results = run_unit_tests(snippet_tests)

      // Assert
      results
      |> should()
      |> equal([
        #("returns user by ID", Passed),
        #("stores Alice first in the user list", Passed),
      ])
      |> or_fail_with("Black box tests should pass")
    }),
    it("focused tests pass", fn() {
      // Arrange
      let snippet_tests = testing_guide_examples.one_assertion_tests()

      // Act
      let results = run_unit_tests(snippet_tests)

      // Assert
      results
      |> should()
      |> equal([
        #("returns created user", Passed),
        #("sets correct name", Passed),
      ])
      |> or_fail_with("Focused tests should pass")
    }),
    it("multiple assertions test passes", fn() {
      // Arrange
      let snippet_tests = testing_guide_examples.multiple_assertions_test()

      // Act
      let results = run_unit_tests(snippet_tests)

      // Assert
      results
      |> should()
      |> equal([#("creates user correctly", Passed)])
      |> or_fail_with("Multiple assertions test should pass")
    }),
    it("arrange act assert test passes", fn() {
      // Arrange
      let snippet_tests = testing_guide_examples.arrange_act_assert_test()

      // Act
      let results = run_unit_tests(snippet_tests)

      // Assert
      results
      |> should()
      |> equal([#("uppercases string", Passed)])
      |> or_fail_with("Arrange act assert test should pass")
    }),
    it("create_user rejects an email without @", fn() {
      // Arrange
      let email = "alice.example.com"

      // Act
      let result = testing_guide_user.create_user("Alice", email)

      // Assert
      result
      |> should()
      |> equal(Error("Email must contain @"))
      |> or_fail_with("create_user should reject the email")
    }),
  ])
}

fn controllers_guide_tests() -> UnitTest {
  describe("controllers and models guide", [
    it("show returns the task page", fn() {
      // Arrange
      let request = task_request("1")

      // Act
      let response =
        controllers_guide_controller.show(
          request,
          AppContext("test-id"),
          task_services(),
        )

      // Assert
      response
      |> should()
      |> equal(html_response(200, "<h1>Write the guide</h1>"))
      |> or_fail_with("show should return the task page")
    }),
    it("show returns 404 JSON for a missing task", fn() {
      // Arrange
      let request = task_request("99")

      // Act
      let response =
        controllers_guide_controller.show(
          request,
          AppContext("test-id"),
          task_services(),
        )

      // Assert
      response
      |> should()
      |> equal(json_response(404, "{\"error\":\"Task not found\"}"))
      |> or_fail_with("show should return 404")
    }),
    it("show returns 400 JSON for an id that is not a number", fn() {
      // Arrange
      let request = task_request("abc")

      // Act
      let response =
        controllers_guide_controller.show(
          request,
          AppContext("test-id"),
          task_services(),
        )

      // Assert
      response
      |> should()
      |> equal(json_response(400, "{\"error\":\"id must be an integer\"}"))
      |> or_fail_with("show should return 400")
    }),
    it("show has the Controller type", fn() {
      // Arrange
      let controller: controllers_guide_controller.Controller(
        AppContext,
        Services,
      ) = controllers_guide_controller.show

      // Act
      let response =
        controller(task_request("1"), AppContext("test-id"), task_services())

      // Assert
      response.status
      |> should()
      |> equal(200)
      |> or_fail_with("The controller should return 200")
    }),
    it("to_json writes the task as JSON", fn() {
      // Arrange
      let task = Task(id: 1, title: "Write the guide", completed: False)

      // Act
      let json = controllers_guide_task_view.to_json(task)

      // Assert
      json
      |> should()
      |> equal("{\"id\":1,\"title\":\"Write the guide\",\"completed\":false}")
      |> or_fail_with("to_json should write the task")
    }),
    it("handle_error hides the Unauthorized message", fn() {
      // Arrange
      let err = error.Unauthorized("token expired")

      // Act
      let response = controllers_guide_response_helpers.handle_error(err)

      // Assert
      response
      |> should()
      |> equal(json_response(401, "{\"error\":\"Unauthorized\"}"))
      |> or_fail_with("handle_error should return 401")
    }),
    it("handle_error escapes quotes in the message", fn() {
      // Arrange
      let err = error.UnprocessableContent("name \"x\" is taken")

      // Act
      let response = controllers_guide_response_helpers.handle_error(err)

      // Assert
      response
      |> should()
      |> equal(json_response(422, "{\"error\":\"name \\\"x\\\" is taken\"}"))
      |> or_fail_with("handle_error should return valid JSON")
    }),
    it("multi-format show returns JSON for .json", fn() {
      // Arrange
      let request = task_request("1.json")

      // Act
      let response =
        controllers_guide_multi_format.show(
          request,
          AppContext("test-id"),
          task_services(),
        )

      // Assert
      response
      |> should()
      |> equal(json_response(
        200,
        "{\"id\":1,\"title\":\"Write the guide\",\"completed\":false}",
      ))
      |> or_fail_with("show should return JSON")
    }),
    it("multi-format show returns the card for .html", fn() {
      // Arrange
      let request = task_request("1.html")

      // Act
      let response =
        controllers_guide_multi_format.show(
          request,
          AppContext("test-id"),
          task_services(),
        )

      // Assert
      response
      |> should()
      |> equal(html_response(200, "<div class=\"task\">Write the guide</div>"))
      |> or_fail_with("show should return the card")
    }),
    it("multi-format show returns JSON with no extension", fn() {
      // Arrange
      let request = task_request("1")

      // Act
      let response =
        controllers_guide_multi_format.show(
          request,
          AppContext("test-id"),
          task_services(),
        )

      // Assert
      response
      |> should()
      |> equal(json_response(
        200,
        "{\"id\":1,\"title\":\"Write the guide\",\"completed\":false}",
      ))
      |> or_fail_with("show should default to JSON")
    }),
    it("multi-format show returns 404 for a missing task", fn() {
      // Arrange
      let request = task_request("7.json")

      // Act
      let response =
        controllers_guide_multi_format.show(
          request,
          AppContext("test-id"),
          task_services(),
        )

      // Assert
      response.status
      |> should()
      |> equal(404)
      |> or_fail_with("show should return 404")
    }),
  ])
}

fn task_request(id: String) -> request.Request {
  test_request.create_request_with_params(Get, "/tasks/" <> id, [#("id", id)])
}

fn task_services() -> Services {
  Services(
    database: Database(
      connection: Connection(tasks: [
        Task(id: 1, title: "Write the guide", completed: False),
      ]),
    ),
  )
}

fn file_uploads_guide_tests() -> UnitTest {
  describe("file uploads guide", [
    it("upload returns 201 for a valid file", fn() {
      // Arrange
      let directory = create_upload_directory("upload_created")
      let request = multipart_request([#("notes.txt", "text/plain", "hello")])

      // Act
      let response =
        file_uploads_guide_upload.upload(
          request,
          AppContext("test-id"),
          file_uploads_guide_upload.Services(upload_directory: directory),
        )

      // Assert
      response.status
      |> should()
      |> equal(201)
      |> or_fail_with("upload should return 201")
    }),
    it("upload saves the file content", fn() {
      // Arrange
      let directory = create_upload_directory("upload_saved")
      let request = multipart_request([#("notes.txt", "text/plain", "hello")])
      let services =
        file_uploads_guide_upload.Services(upload_directory: directory)
      let _ =
        file_uploads_guide_upload.upload(
          request,
          AppContext("test-id"),
          services,
        )

      // Act
      let contents = read_saved_files(directory)

      // Assert
      contents
      |> should()
      |> equal(["hello"])
      |> or_fail_with("upload should save the content")
    }),
    it("upload returns 400 without a multipart body", fn() {
      // Arrange
      let request = test_request.create_request_with_body(Post, "/upload", "x")

      // Act
      let response =
        file_uploads_guide_upload.upload(
          request,
          AppContext("test-id"),
          file_uploads_guide_upload.Services(upload_directory: "tmp/unused"),
        )

      // Assert
      response
      |> should()
      |> equal(json_response(400, "{\"error\": \"Invalid file\"}"))
      |> or_fail_with("upload should return 400")
    }),
    it("generate_filename keeps the extension", fn() {
      // Arrange
      let original_name = "photo.png"

      // Act
      let filename = file_uploads_guide_upload.generate_filename(original_name)

      // Assert
      #(string.length(filename), string.ends_with(filename, ".png"))
      |> should()
      |> equal(#(36, True))
      |> or_fail_with("Should be 32 hex characters and .png")
    }),
    it("generate_filename adds no extension when the name has none", fn() {
      // Arrange
      let original_name = "README"

      // Act
      let filename = file_uploads_guide_upload.generate_filename(original_name)

      // Assert
      string.length(filename)
      |> should()
      |> equal(32)
      |> or_fail_with("Should be 32 hex characters only")
    }),
    it("generate_filename sanitizes the extension", fn() {
      // Arrange
      let original_name = "notes.t\"xt"

      // Act
      let filename = file_uploads_guide_upload.generate_filename(original_name)

      // Assert
      string.ends_with(filename, ".t_xt")
      |> should()
      |> equal(True)
      |> or_fail_with("Should replace the quote in the extension")
    }),
    it("sanitize_filename replaces slashes", fn() {
      // Arrange
      let filename = "../etc/passwd"

      // Act
      let sanitized = file_uploads_guide_upload.sanitize_filename(filename)

      // Assert
      sanitized
      |> should()
      |> equal(".._etc_passwd")
      |> or_fail_with("Should replace slashes")
    }),
    it("validated upload returns 201 for a PNG", fn() {
      // Arrange
      let directory = create_upload_directory("validation_created")
      let request = multipart_request([#("photo.png", "image/png", "png")])

      // Act
      let response =
        file_uploads_guide_validation.upload(
          request,
          AppContext("test-id"),
          file_uploads_guide_upload.Services(upload_directory: directory),
        )

      // Assert
      response.status
      |> should()
      |> equal(201)
      |> or_fail_with("upload should return 201")
    }),
    it("validated upload returns 413 for a file over 10MB", fn() {
      // Arrange
      let content = string.repeat("a", 10_000_001)
      let request = multipart_request([#("photo.png", "image/png", content)])

      // Act
      let response =
        file_uploads_guide_validation.upload(
          request,
          AppContext("test-id"),
          file_uploads_guide_upload.Services(upload_directory: "tmp/unused"),
        )

      // Assert
      response
      |> should()
      |> equal(json_response(413, "{\"error\":\"File too large (max 10MB)\"}"))
      |> or_fail_with("upload should return 413")
    }),
    it("validated upload returns 415 for a text file", fn() {
      // Arrange
      let request = multipart_request([#("notes.txt", "text/plain", "hello")])

      // Act
      let response =
        file_uploads_guide_validation.upload(
          request,
          AppContext("test-id"),
          file_uploads_guide_upload.Services(upload_directory: "tmp/unused"),
        )

      // Assert
      response
      |> should()
      |> equal(json_response(415, "{\"error\":\"Unsupported file type\"}"))
      |> or_fail_with("upload should return 415")
    }),
    it("validate_file_type accepts a PDF", fn() {
      // Arrange
      let content_type = "application/pdf"

      // Act
      let result = file_uploads_guide_file_type.validate_file_type(content_type)

      // Assert
      result
      |> should()
      |> equal(Ok(Nil))
      |> or_fail_with("PDF should be allowed")
    }),
    it("upload_multiple returns 201 for two files", fn() {
      // Arrange
      let directory = create_upload_directory("multiple_created")
      let request =
        multipart_request([
          #("a.txt", "text/plain", "first"),
          #("b.txt", "text/plain", "second"),
        ])

      // Act
      let response =
        file_uploads_guide_multiple.upload_multiple(
          request,
          AppContext("test-id"),
          file_uploads_guide_upload.Services(upload_directory: directory),
        )

      // Assert
      response.status
      |> should()
      |> equal(201)
      |> or_fail_with("upload_multiple should return 201")
    }),
    it("upload_multiple saves both files", fn() {
      // Arrange
      let directory = create_upload_directory("multiple_saved")
      let request =
        multipart_request([
          #("a.txt", "text/plain", "first"),
          #("b.txt", "text/plain", "second"),
        ])
      let services =
        file_uploads_guide_upload.Services(upload_directory: directory)
      let _ =
        file_uploads_guide_multiple.upload_multiple(
          request,
          AppContext("test-id"),
          services,
        )

      // Act
      let contents = read_saved_files(directory)

      // Assert
      contents
      |> should()
      |> equal(["first", "second"])
      |> or_fail_with("upload_multiple should save both files")
    }),
    it("upload_multiple returns 500 when the directory is missing", fn() {
      // Arrange
      let request = multipart_request([#("a.txt", "text/plain", "first")])

      // Act
      let response =
        file_uploads_guide_multiple.upload_multiple(
          request,
          AppContext("test-id"),
          file_uploads_guide_upload.Services(
            upload_directory: "tmp/file_uploads_guide/missing",
          ),
        )

      // Assert
      response
      |> should()
      |> equal(json_response(500, "{\"error\": \"Some files failed\"}"))
      |> or_fail_with("upload_multiple should return 500")
    }),
    it("save_to_s3 returns the file name", fn() {
      // Arrange
      let s3_client = client.new() |> client.recorder(start_s3_recorder())

      // Act
      let result =
        file_uploads_guide_s3.save_to_s3(s3_client, "report.pdf", "PDF content")

      // Assert
      result
      |> should()
      |> equal(Ok("report.pdf"))
      |> or_fail_with("save_to_s3 should return the file name")
    }),
    it("download returns the file content", fn() {
      // Arrange
      let directory = create_upload_directory("download_found")
      let _ = simplifile.write(directory <> "/report.pdf", "PDF content")
      let request =
        test_request.create_request_with_params(Get, "/files/report.pdf", [
          #("filename", "report.pdf"),
        ])

      // Act
      let response =
        file_uploads_guide_download.download(
          request,
          AppContext("test-id"),
          file_uploads_guide_upload.Services(upload_directory: directory),
        )

      // Assert
      response.body
      |> should()
      |> equal(response.Bytes(bit_array.from_string("PDF content")))
      |> or_fail_with("download should return the content")
    }),
    it("download returns 404 for a missing file", fn() {
      // Arrange
      let directory = create_upload_directory("download_missing")
      let request =
        test_request.create_request_with_params(Get, "/files/gone.pdf", [
          #("filename", "gone.pdf"),
        ])

      // Act
      let response =
        file_uploads_guide_download.download(
          request,
          AppContext("test-id"),
          file_uploads_guide_upload.Services(upload_directory: directory),
        )

      // Assert
      response
      |> should()
      |> equal(json_response(404, "{\"error\":\"File not found\"}"))
      |> or_fail_with("download should return 404")
    }),
    it("upload_image returns 415 for a text file", fn() {
      // Arrange
      let request = multipart_request([#("notes.txt", "text/plain", "hello")])

      // Act
      let response =
        file_uploads_guide_image.upload_image(
          request,
          AppContext("test-id"),
          file_uploads_guide_upload.Services(upload_directory: "tmp/unused"),
        )

      // Assert
      response
      |> should()
      |> equal(json_response(415, "{\"error\":\"Unsupported image type\"}"))
      |> or_fail_with("upload_image should return 415")
    }),
    it("upload_image returns 500 when the resize fails", fn() {
      // Arrange
      let request = multipart_request([#("photo.png", "image/png", "png")])

      // Act
      let response =
        file_uploads_guide_image.upload_image(
          request,
          AppContext("test-id"),
          file_uploads_guide_upload.Services(upload_directory: "tmp/unused"),
        )

      // Assert
      response
      |> should()
      |> equal(json_response(500, "{\"error\": \"Resize failed\"}"))
      |> or_fail_with("upload_image should return 500")
    }),
  ])
}

const multipart_boundary = "dream-guide-boundary"

fn multipart_request(
  files: List(#(String, String, String)),
) -> request.Request {
  let body =
    list.map(files, multipart_part)
    |> string.concat()
  request.Request(
    ..test_request.create_request_with_body(
      Post,
      "/upload",
      body <> "--" <> multipart_boundary <> "--\r\n",
    ),
    content_type: Some("multipart/form-data; boundary=" <> multipart_boundary),
  )
}

fn multipart_part(file: #(String, String, String)) -> String {
  let #(filename, content_type, content) = file
  "--"
  <> multipart_boundary
  <> "\r\nContent-Disposition: form-data; name=\"file\"; filename=\""
  <> filename
  <> "\"\r\nContent-Type: "
  <> content_type
  <> "\r\n\r\n"
  <> content
  <> "\r\n"
}

fn create_upload_directory(name: String) -> String {
  let directory = "tmp/file_uploads_guide/" <> name
  let _ = simplifile.delete_all([directory])
  let _ = simplifile.create_directory_all(directory)
  directory
}

fn read_saved_files(directory: String) -> List(String) {
  simplifile.read_directory(directory)
  |> result.unwrap([])
  |> list.filter_map(fn(name) { simplifile.read(directory <> "/" <> name) })
  |> list.sort(string.compare)
}

fn start_s3_recorder() -> recorder.Recorder {
  let assert Ok(s3_recorder) =
    recorder.new()
    |> recorder.directory("test/snippets/file_uploads_guide_recordings")
    |> recorder.mode("playback")
    |> recorder.start()
  s3_recorder
}

// ============================================================================
// Helpers
// ============================================================================

fn run_unit_tests(snippet_tests: UnitTest) -> List(#(String, Status)) {
  unit.to_test_cases("snippet", snippet_tests)
  |> runner.run_all()
  |> list.map(fn(result) { #(result.name, result.status) })
  |> list.sort(fn(left, right) { string.compare(left.0, right.0) })
}

fn run_unit_suite(snippet_tests: UnitTest) -> List(#(String, Status)) {
  unit.to_test_suite("snippet", snippet_tests)
  |> runner.run_suite()
  |> list.map(fn(result) { #(result.name, result.status) })
  |> list.sort(fn(left, right) { string.compare(left.0, right.0) })
}

@external(erlang, "testing_guide_snippets_ffi", "run_main_in_new_vm")
fn run_main_in_new_vm(module: String) -> Int
