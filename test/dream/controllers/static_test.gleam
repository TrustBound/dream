//// Tests for dream/controllers/static module.
////
//// Each test builds its own folder under build/static_controller_test, so
//// tests that run at the same time do not share files.

import dream/controllers/static
import dream/http/header.{Header}
import dream/http/request.{Get}
import dream/http/response.{type Response, Bytes, Response, Text}
import dream_test/matchers.{be_equal, contain_string, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{type UnitNode, describe, group, it}
import fixtures/request as test_request
import gleam/option
import matchers/extract_body_text.{extract_body_text}
import matchers/extract_response_status.{extract_response_status}
import simplifile

const fixture_root = "build/static_controller_test"

/// The PNG signature and the start of an IHDR chunk. The byte 0x89 makes
/// it invalid UTF-8.
const png_bytes = <<
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
  0x48, 0x44, 0x52,
>>

// ============================================================================
// Tests
// ============================================================================

pub fn tests() -> TestSuite {
  describe("static", [
    file_tests(),
    directory_tests(),
    directory_listing_tests(),
  ])
}

fn file_tests() -> UnitNode {
  group("files", [
    it("serves a text file with its MIME type and length", fn() {
      // Arrange
      let root = fresh_directory("text_file")
      let assert Ok(Nil) = simplifile.write(root <> "/app.css", "body {}")

      // Act
      let response = serve_path(root, "app.css", static.default_config())

      // Assert
      response
      |> should()
      |> be_equal(Response(
        status: 200,
        body: Text("body {}"),
        headers: [
          Header("Content-Type", "text/css"),
          Header("Content-Length", "7"),
        ],
        cookies: [],
        content_type: option.Some("text/css"),
      ))
      |> or_fail_with("Should serve app.css as text/css with length 7")
    }),
    it("serves a file without an extension as application/octet-stream", fn() {
      // Arrange
      let root = fresh_directory("no_extension")
      let assert Ok(Nil) = simplifile.write(root <> "/LICENSE", "MIT")

      // Act
      let response = serve_path(root, "LICENSE", static.default_config())

      // Assert
      response.content_type
      |> should()
      |> be_equal(option.Some("application/octet-stream"))
      |> or_fail_with("A file with no extension should be octet-stream")
    }),
    it("returns the default 404 for a file that cannot be read", fn() {
      // Arrange
      let root = fresh_directory("unreadable_file")
      let path = root <> "/secret.txt"
      let assert Ok(Nil) = simplifile.write(path, "hidden")
      let assert Ok(Nil) = simplifile.set_permissions_octal(path, 0o000)

      // Act
      let response = serve_path(root, "secret.txt", static.default_config())
      let assert Ok(Nil) = simplifile.set_permissions_octal(path, 0o644)

      // Assert
      response
      |> should()
      |> be_equal(default_not_found())
      |> or_fail_with("A file that cannot be read should get the default 404")
    }),
    it("serves the exact bytes of a binary file", fn() {
      // Arrange
      let root = fresh_directory("binary_file")
      let assert Ok(Nil) =
        simplifile.write_bits(root <> "/pixel.png", png_bytes)

      // Act
      let response = serve_path(root, "pixel.png", static.default_config())

      // Assert
      response
      |> should()
      |> be_equal(Response(
        status: 200,
        body: Bytes(png_bytes),
        headers: [
          Header("Content-Type", "image/png"),
          Header("Content-Length", "16"),
        ],
        cookies: [],
        content_type: option.Some("image/png"),
      ))
      |> or_fail_with("A PNG should be served as its 16 bytes, as image/png")
    }),
    it("counts the bytes of a UTF-8 text file in its length", fn() {
      // Arrange
      let root = fresh_directory("utf8_file")
      let assert Ok(Nil) = simplifile.write(root <> "/note.txt", "héllo ✓")

      // Act
      let response = serve_path(root, "note.txt", static.default_config())

      // Assert
      response
      |> should()
      |> be_equal(Response(
        status: 200,
        body: Text("héllo ✓"),
        headers: [
          Header("Content-Type", "text/plain"),
          Header("Content-Length", "10"),
        ],
        cookies: [],
        content_type: option.Some("text/plain"),
      ))
      |> or_fail_with("The UTF-8 text is 10 bytes")
    }),
    it("serves an empty file with length 0", fn() {
      // Arrange
      let root = fresh_directory("empty_file")
      let assert Ok(Nil) = simplifile.write(root <> "/empty.txt", "")

      // Act
      let response = serve_path(root, "empty.txt", static.default_config())

      // Assert
      response
      |> should()
      |> be_equal(Response(
        status: 200,
        body: Text(""),
        headers: [
          Header("Content-Type", "text/plain"),
          Header("Content-Length", "0"),
        ],
        cookies: [],
        content_type: option.Some("text/plain"),
      ))
      |> or_fail_with("An empty file should be 200 with length 0")
    }),
  ])
}

fn directory_tests() -> UnitNode {
  group("directories", [
    it("serves index.html for the root when the file path is empty", fn() {
      // Arrange
      let root = fresh_directory("root_index")
      let assert Ok(Nil) =
        simplifile.write(root <> "/index.html", "<h1>Home</h1>")

      // Act
      let response = serve_path(root, "", static.default_config())

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("<h1>Home</h1>")
      |> or_fail_with("An empty file path should serve the root index.html")
    }),
    it("serves index.html of a sub-directory", fn() {
      // Arrange
      let root = fresh_directory("sub_index")
      let assert Ok(Nil) = simplifile.create_directory_all(root <> "/docs")
      let assert Ok(Nil) =
        simplifile.write(root <> "/docs/index.html", "<h1>Docs</h1>")

      // Act
      let response = serve_path(root, "docs", static.default_config())

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("<h1>Docs</h1>")
      |> or_fail_with("A directory should serve its index.html")
    }),
    it("returns 404 for a directory without index.html", fn() {
      // Arrange
      let root = fresh_directory("no_index")
      let assert Ok(Nil) = simplifile.create_directory_all(root <> "/empty")

      // Act
      let response = serve_path(root, "empty", static.default_config())

      // Assert
      response
      |> should()
      |> be_equal(default_not_found())
      |> or_fail_with("A directory without index.html should get a 404")
    }),
    it("does not serve index.html when the index is turned off", fn() {
      // Arrange
      let root = fresh_directory("index_off")
      let assert Ok(Nil) =
        simplifile.write(root <> "/index.html", "<h1>Home</h1>")
      let config = static.without_index(static.default_config())

      // Act
      let response = serve_path(root, "", config)

      // Assert
      response
      |> should()
      |> extract_response_status()
      |> be_equal(404)
      |> or_fail_with("without_index should not serve index.html")
    }),
    it("uses the custom 404 handler for a directory without an index", fn() {
      // Arrange
      let root = fresh_directory("custom_not_found")
      let config =
        static.default_config()
        |> static.without_index()
        |> static.with_custom_404(custom_not_found)

      // Act
      let response = serve_path(root, "", config)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("custom not found")
      |> or_fail_with("The custom 404 handler should answer")
    }),
  ])
}

fn directory_listing_tests() -> UnitNode {
  group("directory listing", [
    it("lists the sorted entries of a directory as HTML", fn() {
      // Arrange
      let root = fresh_directory("listing")
      let assert Ok(Nil) = simplifile.write(root <> "/b.txt", "b")
      let assert Ok(Nil) = simplifile.write(root <> "/a.txt", "a")
      let config =
        static.default_config()
        |> static.with_directory_listing()

      // Act
      let response = serve_path(root, "", config)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> contain_string(
        "    <li><a href=\"a.txt\">a.txt</a></li>\n    <li><a href=\"b.txt\">b.txt</a></li>",
      )
      |> or_fail_with("The listing should link each entry in sorted order")
    }),
    it("titles the listing with the request path", fn() {
      // Arrange
      let root = fresh_directory("listing_title")
      let config =
        static.default_config()
        |> static.with_directory_listing()

      // Act
      let response = serve_path(root, "", config)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> contain_string("<title>Index of /assets/</title>")
      |> or_fail_with("The listing title should name the request path")
    }),
    it("answers a listing with status 200 and an HTML content type", fn() {
      // Arrange
      let root = fresh_directory("listing_headers")
      let config =
        static.default_config()
        |> static.with_directory_listing()

      // Act
      let response = serve_path(root, "", config)

      // Assert
      #(response.status, response.headers, response.content_type)
      |> should()
      |> be_equal(#(
        200,
        [Header("Content-Type", "text/html; charset=utf-8")],
        option.Some("text/html; charset=utf-8"),
      ))
      |> or_fail_with("A listing should be 200 text/html")
    }),
    it("returns the default 404 when the directory cannot be read", fn() {
      // Arrange
      let root = fresh_directory("unreadable_directory")
      let directory = root <> "/locked"
      let assert Ok(Nil) = simplifile.create_directory_all(directory)
      let assert Ok(Nil) = simplifile.set_permissions_octal(directory, 0o000)
      let config =
        static.default_config()
        |> static.with_directory_listing()

      // Act
      let response = serve_path(root, "locked", config)
      let assert Ok(Nil) = simplifile.set_permissions_octal(directory, 0o755)

      // Assert
      response
      |> should()
      |> be_equal(default_not_found())
      |> or_fail_with("A directory that cannot be read should get the 404")
    }),
    it("escapes a file name with markup in the link text and href", fn() {
      // Arrange
      let root = fresh_directory("listing_markup")
      let name = "<img src=x onerror=\"alert(1)\">.txt"
      let assert Ok(Nil) = simplifile.write(root <> "/" <> name, "x")
      let config =
        static.default_config()
        |> static.with_directory_listing()

      // Act
      let response = serve_path(root, "", config)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> contain_string(
        "    <li><a href=\"%3Cimg%20src%3Dx%20onerror%3D%22alert%281%29%22%3E.txt\">&lt;img src=x onerror=&quot;alert(1)&quot;&gt;.txt</a></li>",
      )
      |> or_fail_with("The name should be percent-encoded in href and escaped")
    }),
    it("encodes a space and a non-ASCII letter in the href", fn() {
      // Arrange
      let root = fresh_directory("listing_unicode")
      let assert Ok(Nil) = simplifile.write(root <> "/café menu.txt", "x")
      let config =
        static.default_config()
        |> static.with_directory_listing()

      // Act
      let response = serve_path(root, "", config)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> contain_string(
        "    <li><a href=\"caf%C3%A9%20menu.txt\">café menu.txt</a></li>",
      )
      |> or_fail_with("The href should hold the UTF-8 bytes percent-encoded")
    }),
    it("escapes markup in the request path of the title", fn() {
      // Arrange
      let root = fresh_directory("listing_hostile_path")
      let config =
        static.default_config()
        |> static.with_directory_listing()

      // Act
      let response =
        static.serve(
          request: test_request.create_request(Get, "/a<b>&\"'/"),
          context: Nil,
          services: Nil,
          root: root,
          filepath: "",
          config: config,
        )

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> contain_string("<title>Index of /a&lt;b&gt;&amp;&quot;&#39;/</title>")
      |> or_fail_with("The title should escape the request path")
    }),
  ])
}

// ============================================================================
// Helpers
// ============================================================================

fn serve_path(
  root: String,
  filepath: String,
  config: static.Config(Nil, Nil),
) -> Response {
  static.serve(
    request: test_request.create_request(Get, "/assets/"),
    context: Nil,
    services: Nil,
    root: root,
    filepath: filepath,
    config: config,
  )
}

fn custom_not_found(_request, _context: Nil, _services: Nil) -> Response {
  response.text_response(404, "custom not found")
}

fn default_not_found() -> Response {
  Response(
    status: 404,
    body: Text("<h1>404 Not Found</h1>"),
    headers: [Header("Content-Type", "text/html; charset=utf-8")],
    cookies: [],
    content_type: option.Some("text/html; charset=utf-8"),
  )
}

/// Returns an empty folder for one test. A folder that an earlier run left
/// without permissions gets them back first, so it can be deleted.
fn fresh_directory(name: String) -> String {
  let path = fixture_root <> "/" <> name
  remove_directory(path)
  let assert Ok(Nil) = simplifile.create_directory_all(path)
  path
}

fn remove_directory(path: String) -> Nil {
  case simplifile.is_directory(path) {
    Ok(True) -> {
      let assert Ok(Nil) = simplifile.set_permissions_octal(path, 0o755)
      let assert Ok(Nil) = restore_child_permissions(path)
      let assert Ok(Nil) = simplifile.delete(path)
      Nil
    }
    _ -> Nil
  }
}

fn restore_child_permissions(
  path: String,
) -> Result(Nil, simplifile.FileError) {
  case simplifile.read_directory(path) {
    Ok(entries) -> restore_each(path, entries)
    Error(error) -> Error(error)
  }
}

fn restore_each(
  path: String,
  entries: List(String),
) -> Result(Nil, simplifile.FileError) {
  case entries {
    [] -> Ok(Nil)
    [entry, ..rest] ->
      case simplifile.set_permissions_octal(path <> "/" <> entry, 0o755) {
        Ok(Nil) -> restore_each(path, rest)
        Error(error) -> Error(error)
      }
  }
}
