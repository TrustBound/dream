//// Secure static file serving
////
//// Serve files from disk with built-in security. Handles CSS, JavaScript, images,
//// and any other static assets your application needs.
////
//// ## Quick Setup
////
//// ```gleam
//// import dream/controllers/static
//// import dream/core/http/transaction.{get_param}
////
//// pub fn serve_assets(request, ctx, svc) {
////   let assert Ok(path) = get_param(request, "path")
////   static.serve(
////     request: request,
////     context: ctx,
////     services: svc,
////     root: "./public",
////     filepath: path.value,
////     config: static.default_config(),
////   )
//// }
////
//// // In your router:
//// router.route(Get, "/assets/**path", serve_assets, [])
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
//// - **Index serving** - Serves `index.html` for directory requests
//// - **Directory listing** - Optional file browser (disabled by default)
//// - **Custom 404s** - Use your own not-found handler

import dream/core/http/transaction.{
  type Request, type Response, Header, Response, Text,
}
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/string
import marceau
import simplifile

/// Configuration for static file serving
///
//// Control how directories and missing files are handled.
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
//// - Serves `index.html` for directories
//// - No directory listing
//// - Standard 404 response for missing files
pub fn default_config() -> Config(context, services) {
  Config(
    serve_index: True,
    allow_directory_listing: False,
    not_found_handler: option.None,
  )
}

/// Enable directory listing
///
//// Shows a file browser when a directory has no `index.html`. Use this for
//// development or when you want users to browse files. Don't enable in production
//// unless you specifically want directory browsing.
pub fn with_directory_listing(
  config: Config(context, services),
) -> Config(context, services) {
  Config(..config, allow_directory_listing: True)
}

/// Set custom 404 handler
pub fn with_custom_404(
  config: Config(context, services),
  handler: fn(Request, context, services) -> Response,
) -> Config(context, services) {
  Config(..config, not_found_handler: option.Some(handler))
}

/// Disable automatic index.html serving
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
/// ```gleam
/// pub fn serve_public(request: Request, ctx, svc) -> Response {
///   let assert Ok(filepath) = get_param(request, "filepath")
///   static.serve(
///     request: request,
///     context: ctx,
///     services: svc,
///     root: "./public",
///     filepath: filepath,
///     config: static.default_config(),
///   )
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
  // Try to read as string first (works for text files)
  case simplifile.read(filepath) {
    Ok(content) -> build_file_response(content, filepath)
    Error(_) -> default_404()
  }
}

fn build_file_response(content: String, filepath: String) -> Response {
  let mime = mime_type(filepath)
  let size = string.byte_size(content)

  Response(
    status: 200,
    body: Text(content),
    headers: [
      Header("Content-Type", mime),
      Header("Content-Length", int.to_string(size)),
    ],
    cookies: [],
    content_type: option.Some(mime),
  )
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
  let title = "Index of " <> path
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
      "    <li><a href=\"" <> entry <> "\">" <> entry <> "</a></li>"
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
  // Extract extension from filepath
  case string.split(filepath, ".") |> list.last {
    Ok(ext) -> marceau.extension_to_mime_type(ext)
    Error(_) -> "application/octet-stream"
  }
}
