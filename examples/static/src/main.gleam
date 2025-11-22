import dream/context.{AppContext}
import dream/router
import dream/servers/mist/server.{
  bind, context, listen, router as set_router, services,
} as dream
import gleam/io
import gleam/list
import gleam/string
import router as app_router
import services.{initialize_services}
import simplifile

pub fn main() {
  // Debug: Log working directory
  case simplifile.current_directory() {
    Ok(dir) -> io.println("Server starting from: " <> dir)
    Error(_) -> io.println("Could not determine directory")
  }

  // Debug: Check if public/ exists
  case simplifile.is_directory("./public") {
    Ok(True) -> io.println("✓ ./public exists")
    _ -> io.println("✗ ./public NOT FOUND")
  }

  // Debug: Check if assets/ exists
  case simplifile.is_directory("./assets") {
    Ok(True) -> io.println("✓ ./assets exists")
    _ -> io.println("✗ ./assets NOT FOUND")
  }

  let router_instance = app_router.create_router()

  // Debug: Print registered routes
  case router_instance {
    router.Router(routes) -> {
      io.println(
        "=== REGISTERED "
        <> string.inspect(list.length(routes))
        <> " ROUTES ===",
      )
      list.each(routes, print_route_info)
    }
  }

  io.println("=== STARTING SERVER ON PORT 3000 ===")

  dream.new()
  |> context(AppContext(request_id: ""))
  |> services(initialize_services())
  |> set_router(router_instance)
  |> bind("localhost")
  |> listen(3000)
}

fn print_route_info(route: router.Route(_, _)) {
  io.println("  " <> string.inspect(route.method) <> " " <> route.path)
}
