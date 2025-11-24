//// Static file serving controllers for the example app

import dream/context.{type EmptyContext}
import dream/controllers/static
import dream/http/request.{type Request, get_param}
import dream/http/response.{type Response, html_response}
import dream/http/status
import dream/router.{type EmptyServices}
import gleam/string

/// Serve files from /public with directory listing
pub fn serve_public(
  request: Request,
  context: EmptyContext,
  services: EmptyServices,
) -> Response {
  case get_param(request, "filepath") {
    Ok(param) ->
      static.serve(
        request: request,
        context: context,
        services: services,
        root: "./public",
        filepath: param.raw,
        config: static.default_config() |> static.with_directory_listing(),
      )
    Error(error_msg) ->
      html_response(
        status.bad_request,
        "<h1>Error</h1><p>" <> error_msg <> "</p>",
      )
  }
}

/// Serve files from /assets without index serving
pub fn serve_assets(
  request: Request,
  context: EmptyContext,
  services: EmptyServices,
) -> Response {
  case get_param(request, "filepath") {
    Ok(param) ->
      static.serve(
        request: request,
        context: context,
        services: services,
        root: "./assets",
        filepath: param.raw,
        config: static.default_config() |> static.without_index(),
      )
    Error(error_msg) ->
      html_response(
        status.bad_request,
        "<h1>Error</h1><p>" <> error_msg <> "</p>",
      )
  }
}

/// Single-segment named wildcard: /files/*filename
pub fn serve_single_file(
  request: Request,
  context: EmptyContext,
  services: EmptyServices,
) -> Response {
  case get_param(request, "filename") {
    Ok(param) ->
      static.serve(
        request: request,
        context: context,
        services: services,
        root: "./public",
        filepath: param.raw,
        config: static.default_config(),
      )
    Error(error_msg) ->
      html_response(
        status.bad_request,
        "<h1>Error</h1><p>" <> error_msg <> "</p>",
      )
  }
}

/// Single-segment anonymous wildcard: /health/*/status
/// No parameters captured, extract from path
pub fn health_status(
  request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  html_response(
    status.ok,
    "<h1>Health Status OK</h1><p>Anonymous wildcard matched: "
      <> request.path
      <> "</p>",
  )
}

/// Extension pattern: /css/*.css
/// Anonymous extension pattern, extract from path
pub fn serve_css_only(
  request: Request,
  context: EmptyContext,
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
  context: EmptyContext,
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
  context: EmptyContext,
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
  context: EmptyContext,
  services: EmptyServices,
) -> Response {
  case get_param(request, "filepath") {
    Ok(param) ->
      static.serve(
        request: request,
        context: context,
        services: services,
        root: "./public",
        filepath: param.raw,
        config: static.default_config()
          |> static.with_custom_404(fn(_req, _ctx, _svc) {
            html_response(
              status.not_found,
              "<h1>Custom 404</h1><p>The requested file does not exist.</p>",
            )
          }),
      )
    Error(error_msg) ->
      html_response(
        status.bad_request,
        "<h1>Error</h1><p>" <> error_msg <> "</p>",
      )
  }
}
