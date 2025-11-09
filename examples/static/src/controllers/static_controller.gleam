//// Static file serving controllers for the example app

import dream/controllers/static
import dream/core/context.{type AppContext}
import dream_helpers/statuses
import dream/core/http/transaction.{type Request, type Response, get_param}
import dream_helpers/http.{html_response}
import dream/core/router.{type EmptyServices}
import gleam/string

/// Serve files from /public with directory listing
pub fn serve_public(
  request: Request,
  context: AppContext,
  services: EmptyServices,
) -> Response {
  let assert Ok(param) = get_param(request, "filepath")

  static.serve(
    request: request,
    context: context,
    services: services,
    root: "./public",
    filepath: param.raw,
    config: static.default_config() |> static.with_directory_listing(),
  )
}

/// Serve files from /assets without index serving
pub fn serve_assets(
  request: Request,
  context: AppContext,
  services: EmptyServices,
) -> Response {
  let assert Ok(param) = get_param(request, "filepath")

  static.serve(
    request: request,
    context: context,
    services: services,
    root: "./assets",
    filepath: param.raw,
    config: static.default_config() |> static.without_index(),
  )
}

/// Single-segment named wildcard: /files/*filename
pub fn serve_single_file(
  request: Request,
  context: AppContext,
  services: EmptyServices,
) -> Response {
  let assert Ok(param) = get_param(request, "filename")

  static.serve(
    request: request,
    context: context,
    services: services,
    root: "./public",
    filepath: param.raw,
    config: static.default_config(),
  )
}

/// Single-segment anonymous wildcard: /health/*/status
/// No parameters captured, extract from path
pub fn health_status(
  request: Request,
  _context: AppContext,
  _services: EmptyServices,
) -> Response {
  html_response(
    statuses.ok_status(),
    "<h1>Health Status OK</h1><p>Anonymous wildcard matched: "
      <> request.path
      <> "</p>",
  )
}

/// Extension pattern: /css/*.css
/// Anonymous extension pattern, extract from path
pub fn serve_css_only(
  request: Request,
  context: AppContext,
  services: EmptyServices,
) -> Response {
  // Extract filename from /css/filename.css
  let filename = string.replace(request.path, "/css/", "")

  static.serve(
    request: request,
    context: context,
    services: services,
    root: "./public",
    filepath: filename,
    config: static.default_config(),
  )
}

/// Brace expansion: /images/*.{jpg,png,gif,svg}
/// Anonymous extension pattern, extract from path
pub fn serve_image_file(
  request: Request,
  context: AppContext,
  services: EmptyServices,
) -> Response {
  // Extract filename from /images/filename.ext
  let filename = string.replace(request.path, "/images/", "")

  static.serve(
    request: request,
    context: context,
    services: services,
    root: "./public/images",
    filepath: filename,
    config: static.default_config(),
  )
}

/// Multi-wildcard + extension: /photos/**/*.{jpg,png}
/// Anonymous patterns, extract from path
pub fn serve_photo(
  request: Request,
  context: AppContext,
  services: EmptyServices,
) -> Response {
  // Extract path from /photos/path/to/file.ext
  let filepath = string.replace(request.path, "/photos/", "")

  static.serve(
    request: request,
    context: context,
    services: services,
    root: "./public/images",
    filepath: filepath,
    config: static.default_config(),
  )
}

/// Serve with custom 404
pub fn serve_with_custom_404(
  request: Request,
  context: AppContext,
  services: EmptyServices,
) -> Response {
  let assert Ok(param) = get_param(request, "filepath")

  static.serve(
    request: request,
    context: context,
    services: services,
    root: "./public",
    filepath: param.raw,
    config: static.default_config()
      |> static.with_custom_404(fn(_req, _ctx, _svc) {
        html_response(
          statuses.not_found_status(),
          "<h1>Custom 404</h1><p>The requested file does not exist.</p>",
        )
      }),
  )
}
