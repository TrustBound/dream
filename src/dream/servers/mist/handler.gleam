//// Request handler for Mist server
////
//// This module provides handler creation functionality that converts
//// Mist requests to Dream requests, routes them, and converts the
//// response back to Mist format.

import dream/core/dream
import dream/core/router.{type Router}
import dream/servers/mist/request as mist_request
import dream/servers/mist/response as mist_response
import gleam/bytes_tree
import gleam/http/request.{type Request as HttpRequest}
import gleam/http/response as http_response
import mist.{type Connection, type ResponseData, Bytes, read_body}

/// Create a request handler that converts mist requests to Dream requests,
/// routes them, and converts the response back to mist format
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
        // Return error response if body read failed
        http_response.new(400)
        |> http_response.set_body(Bytes(bytes_tree.new()))
      }
    }
  }
}
