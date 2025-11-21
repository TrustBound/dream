//// Request handler for Mist server
////
//// This module provides handler creation functionality that converts
//// Mist requests to Dream requests, routes them, and converts the
//// response back to Mist format.
////
//// This is an internal module used by the Dream server implementation.
//// Most applications won't need to use this directly.

import dream/dream
import dream/router.{type Router}
import dream/servers/mist/request as mist_request
import dream/servers/mist/response as mist_response
import gleam/bytes_tree
import gleam/http/request.{type Request as HttpRequest}
import gleam/http/response as http_response
import mist.{type Connection, type ResponseData, Bytes, read_body}

/// Create a request handler that converts Mist requests to Dream requests
///
/// This function creates the main request handler used by the Mist server.
/// It handles the complete request/response cycle:
///
/// 1. Read the request body (with size limit)
/// 2. Convert Mist request to Dream request format
/// 3. Generate a request ID and update context
/// 4. Route the request through the router
/// 5. Convert Dream response back to Mist format
///
/// ## Parameters
///
/// - `router`: The application's router with all routes configured
/// - `max_body_size`: Maximum allowed request body size in bytes
/// - `template_context`: Template context to clone for each request
/// - `services_instance`: Application services (database, cache, etc.)
/// - `update_context`: Function to update context with request-specific data
///
/// ## Returns
///
/// A function that takes a Mist HTTP request and returns a Mist HTTP response.
/// This function is what you pass to `mist.new()`.
///
/// ## Example
///
/// ```gleam
/// // Internal use - normally called by dream.listen()
/// let handler = handler.create(
///   my_router,
///   10_000_000,  // 10MB max body
///   my_context,
///   my_services,
///   fn(ctx, request_id) { MyContext(..ctx, request_id: request_id) }
/// )
///
/// mist.new(handler)
/// |> mist.port(3000)
/// |> mist.start()
/// ```
pub fn create(
  router: Router(context, services),
  max_body_size: Int,
  template_context: context,
  services_instance: services,
  update_context: fn(context, String) -> context,
) -> fn(HttpRequest(Connection)) -> http_response.Response(ResponseData) {
  fn(mist_req: HttpRequest(Connection)) {
    // Read body once - this consumes the connection
    let body_result = read_body(mist_req, max_body_limit: max_body_size)

    case body_result {
      Ok(req_with_body) -> {
        // Convert mist request to Dream request (immutable HTTP data)
        let #(dream_req, request_id) =
          mist_request.convert(mist_req, req_with_body)

        // Create context for this request by updating template with request_id
        let request_context = update_context(template_context, request_id)

        // Route the request with context and services
        let dream_resp =
          dream.route_request(
            router,
            dream_req,
            request_context,
            services_instance,
          )

        // Convert Dream response back to mist format
        mist_response.convert(dream_resp)
      }
      Error(_) -> {
        // Return error response if body read failed (body too large or read error)
        http_response.new(400)
        |> http_response.set_body(Bytes(bytes_tree.new()))
      }
    }
  }
}
