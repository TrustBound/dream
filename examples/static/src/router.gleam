import controllers/static_controller
import dream/context.{type EmptyContext}
import dream/http/request.{Get}
import dream/router.{type EmptyServices, type Router, route, router}

pub fn create_router() -> Router(EmptyContext, EmptyServices) {
  router()
  // Multi-segment named wildcard: **filepath
  |> route(
    method: Get,
    path: "/public/**filepath",
    controller: static_controller.serve_public,
    middleware: [],
  )
  // Multi-segment named wildcard: **filepath (no index)
  |> route(
    method: Get,
    path: "/assets/**filepath",
    controller: static_controller.serve_assets,
    middleware: [],
  )
  // Single-segment named wildcard: *filename
  |> route(
    method: Get,
    path: "/files/*filename",
    controller: static_controller.serve_single_file,
    middleware: [],
  )
  // Single-segment anonymous wildcard: *
  |> route(
    method: Get,
    path: "/health/*/status",
    controller: static_controller.health_status,
    middleware: [],
  )
  // Extension pattern: *.ext
  |> route(
    method: Get,
    path: "/css/*.css",
    controller: static_controller.serve_css_only,
    middleware: [],
  )
  // Brace expansion extension: *.{ext1,ext2}
  |> route(
    method: Get,
    path: "/images/*.{jpg,png,gif,svg}",
    controller: static_controller.serve_image_file,
    middleware: [],
  )
  // Multi-wildcard + extension in middle
  |> route(
    method: Get,
    path: "/photos/**/*.{jpg,png}",
    controller: static_controller.serve_photo,
    middleware: [],
  )
  // Custom 404 example
  |> route(
    method: Get,
    path: "/custom/**filepath",
    controller: static_controller.serve_with_custom_404,
    middleware: [],
  )
}
