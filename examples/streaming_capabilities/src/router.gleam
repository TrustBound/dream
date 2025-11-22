import controllers/stream_controller
import dream/context.{type AppContext}
import dream/http/request.{Get, Post}
import dream/router.{type Router, router, stream_route}
import middleware/transform_middleware
import services.{type Services}

pub fn create() -> Router(AppContext, Services) {
  router
  // 1. Ingress Streaming (Uploads)
  // POST /upload - Streams data directly to "disk" (simulated)
  |> stream_route(
    method: Post,
    path: "/upload",
    controller: stream_controller.upload,
    middleware: [],
  )
  // 2. Egress Streaming (Downloads)
  // GET /download - Streams generated data back to client
  |> router.route(
    method: Get,
    path: "/download",
    controller: stream_controller.download,
    middleware: [],
  )
  // 3. Bi-Directional Streaming Middleware
  // POST /echo_transform - Uppercase IN -> Underscore OUT
  |> stream_route(
    method: Post,
    path: "/echo_transform",
    controller: stream_controller.echo_transform,
    middleware: [
      transform_middleware.uppercase_incoming,
      transform_middleware.replace_space_outgoing,
    ],
  )
  // 4. Proxy Streaming
  // GET /proxy - Streams from external API to client
  |> router.route(
    method: Get,
    path: "/proxy",
    controller: stream_controller.proxy,
    middleware: [],
  )
}
