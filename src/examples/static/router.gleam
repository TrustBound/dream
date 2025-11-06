import dream/core/context.{type AppContext}
import dream/core/http/transaction.{Get}
import dream/core/router.{type EmptyServices, type Router, route, router}
import examples/static/controllers/static_controller

pub fn create_router() -> Router(AppContext, EmptyServices) {
  router
  // Multi-segment named wildcard: **filepath
  |> route(Get, "/public/**filepath", static_controller.serve_public, [])
  // Multi-segment named wildcard: **filepath (no index)
  |> route(Get, "/assets/**filepath", static_controller.serve_assets, [])
  // Single-segment named wildcard: *filename
  |> route(Get, "/files/*filename", static_controller.serve_single_file, [])
  // Single-segment anonymous wildcard: *
  |> route(Get, "/health/*/status", static_controller.health_status, [])
  // Extension pattern: *.ext
  |> route(Get, "/css/*.css", static_controller.serve_css_only, [])
  // Brace expansion extension: *.{ext1,ext2}
  |> route(
    Get,
    "/images/*.{jpg,png,gif,svg}",
    static_controller.serve_image_file,
    [],
  )
  // Multi-wildcard + extension in middle
  |> route(Get, "/photos/**/*.{jpg,png}", static_controller.serve_photo, [])
  // Custom 404 example
  |> route(
    Get,
    "/custom/**filepath",
    static_controller.serve_with_custom_404,
    [],
  )
}
