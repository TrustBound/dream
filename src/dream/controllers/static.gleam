//// Secure static file serving
////
//// Serve files from disk with built-in security. Handles CSS, JavaScript, images,
//// and any other static assets your application needs.
////
//// ## Quick Setup
////
//// ### Serve assets <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_core_static.gleam#L3-L35"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
////
//// ```gleam
//// import dream/controllers/static.{default_config, serve}
//// import dream/http/request.{type Request, Get, get_param}
//// import dream/http/response.{type Response, json_response}
//// import dream/http/status.{bad_request}
//// import dream/router.{route, router}
//// import gleam/json
////
//// pub fn serve_assets(request: Request, context, services) -> Response {
////   case get_param(request, "path") {
////     // param.raw keeps the file extension
////     Ok(param) ->
////       serve(
////         request: request,
////         context: context,
////         services: services,
////         root: "./public",
////         filepath: param.raw,
////         config: default_config(),
////       )
////     Error(message) -> json_response(bad_request, error_json(message))
////   }
//// }
////
//// // In your router:
//// pub fn asset_router() {
////   router()
////   |> route(
////     method: Get,
////     path: "/assets/**path",
////     controller: serve_assets,
////     middleware: [],
////   )
//// }
//// ```
////
//// ## Security
////
//// Built-in protection against:
//// - Path traversal attacks (`../../../etc/passwd`)
//// - Absolute path access (`/etc/passwd`)
//// - Directory escaping
////
//// Files outside the root directory return 404, never errors that reveal filesystem structure.
////
//// ## Features
////
//// - **MIME type detection** - Automatic content-type headers
//// - **Exact bytes** - A text file is sent as `Text`, and any other file,
////   such as an image, as `Bytes` with its exact bytes
//// - **Index serving** - Serves `index.html` for directory requests
//// - **Directory listing** - Optional file browser (disabled by default).
////   File names and the request path are HTML-escaped, and each link is
////   percent-encoded
//// - **Custom 404s** - Use your own not-found handler
//// Control how directories and missing files are handled.
//// - Serves `index.html` for directories
//// - No directory listing
//// - Standard 404 response for missing files
//// Shows a file browser when a directory has no `index.html`. Use this for
//// development or when you want users to browse files. Don't enable in production
//// unless you specifically want directory browsing.

import dream/http/header.{Header}
import dream/http/request.{type Request}
import dream/http/response.{
  type Response, type ResponseBody, Bytes, Response, Text,
}
import gleam/bit_array
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/string
import marceau
import simplifile

/// Configuration for static file serving
///
pub type Config(context, services) {
  Config(
    /// Whether to serve index.html for directory requests
    serve_index: Bool,
    /// Whether to allow directory listing when no index.html exists
    allow_directory_listing: Bool,
    /// Custom 404 handler (None = default 404 response)
    not_found_handler: Option(fn(Request, context, services) -> Response),
  )
}

/// Default configuration with secure settings
///
/// ## Example
///
/// ### Use the default configuration <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_core_static_default_config.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/controllers/static.{type Config, default_config}
///
/// pub fn asset_config() -> Config(context, services) {
///   // serve_index: True, allow_directory_listing: False, not_found_handler: None
///   default_config()
/// }
/// ```
pub fn default_config() -> Config(context, services) {
  Config(
    serve_index: True,
    allow_directory_listing: False,
    not_found_handler: option.None,
  )
}

/// Enable directory listing
///
/// ## Example
///
/// ### Allow directory listings <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_core_static_with_directory_listing.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/controllers/static.{
///   type Config, default_config, with_directory_listing,
/// }
///
/// pub fn listing_config() -> Config(context, services) {
///   // allow_directory_listing: True
///   default_config()
///   |> with_directory_listing()
/// }
/// ```
pub fn with_directory_listing(
  config: Config(context, services),
) -> Config(context, services) {
  Config(..config, allow_directory_listing: True)
}

/// Set custom 404 handler
///
/// ## Example
///
/// ### Answer a missing file <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_core_static_with_custom_404.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/controllers/static.{default_config, serve, with_custom_404}
/// import dream/http/request.{type Request}
/// import dream/http/response.{type Response, text_response}
/// import dream/http/status.{not_found}
///
/// fn missing_file(_request: Request, _context, _services) -> Response {
///   text_response(not_found, "No such file")
/// }
///
/// pub fn download(request: Request, filepath: String) -> Response {
///   let config =
///     default_config()
///     |> with_custom_404(missing_file)
///   // A file that is not in ./downloads gets the "No such file" response
///   serve(
///     request: request,
///     context: Nil,
///     services: Nil,
///     root: "./downloads",
///     filepath: filepath,
///     config: config,
///   )
/// }
/// ```
pub fn with_custom_404(
  config: Config(context, services),
  handler: fn(Request, context, services) -> Response,
) -> Config(context, services) {
  Config(..config, not_found_handler: option.Some(handler))
}

/// Disable automatic index.html serving
///
/// ## Example
///
/// ### Turn off index files <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_core_static_without_index.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/controllers/static.{type Config, default_config, without_index}
///
/// pub fn no_index_config() -> Config(context, services) {
///   // serve_index: False
///   default_config()
///   |> without_index()
/// }
/// ```
pub fn without_index(
  config: Config(context, services),
) -> Config(context, services) {
  Config(..config, serve_index: False)
}

/// Serve static files from a directory
///
/// Security:
/// - Prevents path traversal attacks (../)
/// - Validates paths stay within root directory
/// - Returns 404 for files outside root
///
/// Usage:
///
/// ### Serve public files <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_core_static_serve.gleam#L3-L23"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/controllers/static.{default_config, serve}
/// import dream/http/request.{type Request, get_param}
/// import dream/http/response.{type Response, json_response}
/// import dream/http/status.{bad_request}
/// import gleam/json
///
/// pub fn serve_public(request: Request, context, services) -> Response {
///   case get_param(request, "filepath") {
///     // param.raw keeps the file extension
///     Ok(param) ->
///       serve(
///         request: request,
///         context: context,
///         services: services,
///         root: "./public",
///         filepath: param.raw,
///         config: default_config(),
///       )
///     Error(message) -> json_response(bad_request, error_json(message))
///   }
/// }
/// ```
pub fn serve(
  request request: Request,
  context context: context,
  services services: services,
  root root: String,
  filepath filepath: String,
  config config: Config(context, services),
) -> Response {
  // Validate path safety
  case is_safe_path(filepath) {
    False -> handle_not_found(request, context, services, config)
    True ->
      serve_validated_path(request, context, services, root, filepath, config)
  }
}

fn serve_validated_path(
  request: Request,
  context: context,
  services: services,
  root: String,
  filepath: String,
  config: Config(context, services),
) -> Response {
  let full_path = case filepath {
    "" -> root
    _ -> root <> "/" <> filepath
  }

  case simplifile.is_file(full_path) {
    Ok(True) -> serve_file(full_path)
    _ ->
      handle_directory_or_missing(request, context, services, full_path, config)
  }
}

fn handle_directory_or_missing(
  request: Request,
  context: context,
  services: services,
  path: String,
  config: Config(context, services),
) -> Response {
  case simplifile.is_directory(path) {
    Ok(True) -> handle_directory(request, context, services, path, config)
    _ -> handle_not_found(request, context, services, config)
  }
}

fn handle_directory(
  request: Request,
  context: context,
  services: services,
  directory: String,
  config: Config(context, services),
) -> Response {
  case config.serve_index {
    True -> {
      case try_serve_index(directory) {
        Ok(response) -> response
        Error(_) ->
          handle_no_index(request, context, services, directory, config)
      }
    }
    False -> handle_no_index(request, context, services, directory, config)
  }
}

fn handle_no_index(
  request: Request,
  context: context,
  services: services,
  directory: String,
  config: Config(context, services),
) -> Response {
  case config.allow_directory_listing {
    True -> generate_directory_listing(directory, request.path)
    False -> handle_not_found(request, context, services, config)
  }
}

fn try_serve_index(directory: String) -> Result(Response, Nil) {
  let index_path = directory <> "/index.html"
  case simplifile.is_file(index_path) {
    Ok(True) -> Ok(serve_file(index_path))
    _ -> Error(Nil)
  }
}

fn serve_file(filepath: String) -> Response {
  case simplifile.read_bits(filepath) {
    Ok(content) -> build_file_response(content, filepath)
    Error(_) -> default_404()
  }
}

/// The body keeps the exact bytes of the file: a file that is valid UTF-8
/// becomes `Text`, and any other file, such as an image, becomes `Bytes`.
fn build_file_response(content: BitArray, filepath: String) -> Response {
  let mime = mime_type(filepath)
  let size = bit_array.byte_size(content)

  Response(
    status: 200,
    body: file_body(content),
    headers: [
      Header("Content-Type", mime),
      Header("Content-Length", int.to_string(size)),
    ],
    cookies: [],
    content_type: option.Some(mime),
  )
}

fn file_body(content: BitArray) -> ResponseBody {
  case bit_array.to_string(content) {
    Ok(text) -> Text(text)
    Error(Nil) -> Bytes(content)
  }
}

fn generate_directory_listing(
  directory: String,
  request_path: String,
) -> Response {
  case simplifile.read_directory(directory) {
    Ok(entries) -> {
      let sorted = list.sort(entries, string.compare)
      let html = build_directory_html(request_path, sorted)
      build_html_response(html)
    }
    Error(_) -> default_404()
  }
}

fn build_html_response(html: String) -> Response {
  Response(
    status: 200,
    body: Text(html),
    headers: [Header("Content-Type", "text/html; charset=utf-8")],
    cookies: [],
    content_type: option.Some("text/html; charset=utf-8"),
  )
}

fn build_directory_html(path: String, entries: List(String)) -> String {
  let title = "Index of " <> escape_html(path)
  let header = "<!DOCTYPE html>
<html>
<head>
  <title>" <> title <> "</title>
  <style>
    body { font-family: system-ui, sans-serif; max-width: 800px; margin: 40px auto; padding: 20px; }
    h1 { border-bottom: 1px solid #ccc; padding-bottom: 10px; }
    ul { list-style: none; padding: 0; }
    li { padding: 8px; border-bottom: 1px solid #eee; }
    li:hover { background: #f5f5f5; }
    a { text-decoration: none; color: #0066cc; }
    a:hover { text-decoration: underline; }
  </style>
</head>
<body>
  <h1>" <> title <> "</h1>
  <ul>
    <li><a href=\"../\">../</a></li>"

  let items =
    entries
    |> list.map(fn(entry) {
      "    <li><a href=\""
      <> percent_encode(entry)
      <> "\">"
      <> escape_html(entry)
      <> "</a></li>"
    })
    |> string.join("\n")

  let footer =
    "
  </ul>
</body>
</html>"

  header <> "\n" <> items <> footer
}

fn handle_not_found(
  request: Request,
  context: context,
  services: services,
  config: Config(context, services),
) -> Response {
  case config.not_found_handler {
    option.Some(handler) -> handler(request, context, services)
    option.None -> default_404()
  }
}

fn default_404() -> Response {
  Response(
    status: 404,
    body: Text("<h1>404 Not Found</h1>"),
    headers: [Header("Content-Type", "text/html; charset=utf-8")],
    cookies: [],
    content_type: option.Some("text/html; charset=utf-8"),
  )
}

/// Validate path doesn't escape root directory
fn is_safe_path(filepath: String) -> Bool {
  // Reject paths with ..
  !string.contains(filepath, "..")
  // Reject absolute paths (but allow empty string for root)
  && !string.starts_with(filepath, "/")
}

/// Detect MIME type from file extension using marceau library
fn mime_type(filepath: String) -> String {
  marceau.extension_to_mime_type(last_dot_segment(filepath))
}

/// The text after the last `.` in `text`, or all of `text` when it has no
/// `.`. A file without an extension gets `application/octet-stream` from
/// marceau.
fn last_dot_segment(text: String) -> String {
  case string.split_once(text, ".") {
    Ok(#(_before, after)) -> last_dot_segment(after)
    Error(Nil) -> text
  }
}

/// Escapes the characters that have a meaning in HTML text and in a quoted
/// attribute value.
fn escape_html(text: String) -> String {
  text
  |> string.replace("&", "&amp;")
  |> string.replace("<", "&lt;")
  |> string.replace(">", "&gt;")
  |> string.replace("\"", "&quot;")
  |> string.replace("'", "&#39;")
}

/// Percent-encodes a file name for use as a relative URL path segment
/// (RFC 3986 section 2.1). Each byte of the UTF-8 name that is not an
/// unreserved character (letters, digits, `-`, `.`, `_` and `~`) becomes
/// `%` and two upper case hex digits, so the name can never end the
/// attribute or become a scheme or a path separator.
fn percent_encode(name: String) -> String {
  name
  |> string.to_utf_codepoints
  |> list.map(percent_encode_codepoint)
  |> string.concat
}

fn percent_encode_codepoint(codepoint: UtfCodepoint) -> String {
  case is_unreserved(string.utf_codepoint_to_int(codepoint)) {
    True -> string.from_utf_codepoints([codepoint])
    False -> percent_encode_bytes(<<codepoint:utf8_codepoint>>, "")
  }
}

fn percent_encode_bytes(bytes: BitArray, encoded: String) -> String {
  case bytes {
    <<byte, rest:bytes>> ->
      percent_encode_bytes(
        rest,
        encoded
          <> "%"
          <> string.pad_start(int.to_base16(byte), to: 2, with: "0"),
      )
    _ -> encoded
  }
}

/// The unreserved characters of RFC 3986 section 2.3: `A` to `Z`, `a` to
/// `z`, `0` to `9`, `-`, `.`, `_` and `~`.
fn is_unreserved(codepoint: Int) -> Bool {
  { codepoint >= 0x41 && codepoint <= 0x5A }
  || { codepoint >= 0x61 && codepoint <= 0x7A }
  || { codepoint >= 0x30 && codepoint <= 0x39 }
  || codepoint == 0x2D
  || codepoint == 0x2E
  || codepoint == 0x5F
  || codepoint == 0x7E
}
