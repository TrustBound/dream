import dream/dream
import dream/http/header.{Header}
import dream/http/request.{type Request, Request}
import dream/http/response.{type Response, Response, Text}
import dream/router.{type Route, type Router, find_route}
import dream/servers/mist/internal
import dream/servers/mist/request as mist_request
import dream/servers/mist/response as mist_response
import gleam/bit_array
import gleam/bytes_tree
import gleam/erlang/atom
import gleam/http/request as http_request
import gleam/http/response as http_response
import gleam/list
import gleam/option
import gleam/result
import gleam/yielder
import mist.{type Connection, type ResponseData, Bytes}

/// Create a request handler that converts Mist requests to Dream requests
///
/// This function creates the main request handler used by the Mist server.
/// It handles the complete request/response cycle:
///
/// 1. Convert Mist request headers/metadata to Dream request
/// 2. Match route to determine if body should be buffered or streamed
/// 3. Read body (buffered) or wrap stream (streaming)
/// 4. Route the request through the router
/// 5. Convert Dream response back to Mist format
/// 6. Handle HTTP → WebSocket upgrades when a controller calls
///    `websocket.upgrade_websocket` (the upgrade response is stashed and
///    returned here instead of a normal HTTP response)
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
pub fn create(
  router: Router(context, services),
  max_body_size: Int,
  template_context: context,
  services_instance: services,
  update_context: fn(context, String) -> context,
) -> fn(http_request.Request(Connection)) ->
  http_response.Response(ResponseData) {
  create_request_handler(
    router,
    max_body_size,
    template_context,
    services_instance,
    update_context,
  )
}

/// Create the request handler function that processes Mist requests
fn create_request_handler(
  router: Router(context, services),
  max_body_size: Int,
  template_context: context,
  services_instance: services,
  update_context: fn(context, String) -> context,
) -> fn(http_request.Request(Connection)) ->
  http_response.Response(ResponseData) {
  fn(mist_request: http_request.Request(Connection)) {
    // 1. Stash the Mist request
    let request_key = atom.create(internal.request_key)
    internal.put(request_key, internal.to_dynamic(mist_request))

    // 2. Initialize response stash to None
    let response_key = atom.create(internal.response_key)
    internal.put(response_key, internal.to_dynamic(option.None))

    // 3. Initialize upgrade stash to None (for deferred SSE upgrades)
    let upgrade_key = atom.create(internal.upgrade_key)
    internal.put(upgrade_key, internal.to_dynamic(option.None))

    // 4. Create a "Lightweight" Request (Headers, Path, Method only)
    let #(partial_request, request_id) =
      mist_request.convert_metadata(mist_request)

    // 5. Find the route using the lightweight request
    let dream_response = case find_route(router, partial_request) {
      option.Some(#(route, params)) -> {
        // Create context for this request by updating template with request_id
        let request_context = update_context(template_context, request_id)

        // Process body and route request
        handle_routed_request(
          mist_request,
          partial_request,
          route,
          params,
          max_body_size,
          request_context,
          services_instance,
        )
      }

      // 404 Not Found - Return immediately without reading body
      option.None -> {
        let dream_response =
          Response(
            status: 404,
            body: Text("Route not found"),
            headers: [Header("Content-Type", "text/plain; charset=utf-8")],
            cookies: [],
            content_type: option.Some("text/plain; charset=utf-8"),
          )
        mist_response.convert(dream_response)
      }
    }

    // 6. Check for upgrade response in stash (WebSocket)
    let raw_upgrade = internal.get(response_key)
    let upgrade_result: option.Option(http_response.Response(ResponseData)) =
      internal.unsafe_coerce(raw_upgrade)

    case upgrade_result {
      option.Some(mist_response) -> mist_response
      option.None -> dream_response
    }
  }
}

fn handle_routed_request(
  mist_request: http_request.Request(Connection),
  partial_request: Request,
  route: Route(context, services),
  params: List(#(String, String)),
  max_body_size: Int,
  request_context: context,
  services_instance: services,
) -> http_response.Response(ResponseData) {
  // 3. DECIDE: Stream or Buffer?
  let final_request_result = case route.streaming {
    True -> prepare_streaming_request(mist_request, partial_request)
    False ->
      prepare_buffered_request(mist_request, partial_request, max_body_size)
  }

  case final_request_result {
    Ok(final_request) -> {
      let dream_response =
        dream.execute_route(
          route,
          final_request,
          params,
          request_context,
          services_instance,
        )

      let upgrade_key = atom.create(internal.upgrade_key)
      let raw_upgrade = internal.get(upgrade_key)
      let maybe_upgrade: option.Option(
        fn(List(#(String, String))) -> http_response.Response(ResponseData),
      ) = internal.unsafe_coerce(raw_upgrade)

      case maybe_upgrade {
        option.Some(perform_upgrade) ->
          case dream_response.status {
            200 -> perform_upgrade(extract_dream_headers(dream_response))
            _ -> mist_response.convert(dream_response)
          }
        option.None -> mist_response.convert(dream_response)
      }
    }
    Error(response) -> response
  }
}

fn prepare_streaming_request(
  mist_request: http_request.Request(Connection),
  partial_request: Request,
) -> Result(Request, http_response.Response(ResponseData)) {
  case mist.stream(mist_request) {
    Ok(chunk_provider) -> {
      let stream = yielder.unfold(chunk_provider, stream_unfolder)
      Ok(Request(..partial_request, stream: option.Some(stream)))
    }
    Error(_) -> Error(bad_request_response())
  }
}

fn stream_unfolder(
  provider: fn(Int) -> Result(mist.Chunk, mist.ReadError),
) -> yielder.Step(BitArray, fn(Int) -> Result(mist.Chunk, mist.ReadError)) {
  // Default chunk size of 64KB
  case provider(65_536) {
    Ok(mist.Chunk(data, next_provider)) -> yielder.Next(data, next_provider)
    Ok(mist.Done) -> yielder.Done
    Error(_) -> yielder.Done
  }
}

fn prepare_buffered_request(
  mist_request: http_request.Request(Connection),
  partial_request: Request,
  max_body_size: Int,
) -> Result(Request, http_response.Response(ResponseData)) {
  case mist.read_body(mist_request, max_body_limit: max_body_size) {
    Ok(request_with_body) -> {
      let body_string =
        bit_array.to_string(request_with_body.body) |> result.unwrap("")
      Ok(Request(..partial_request, body: body_string))
    }
    Error(_) -> Error(bad_request_response())
  }
}

fn extract_dream_headers(response: Response) -> List(#(String, String)) {
  list.map(response.headers, fn(h) {
    let Header(name, value) = h
    #(name, value)
  })
}

fn bad_request_response() -> http_response.Response(ResponseData) {
  http_response.new(400)
  |> http_response.set_body(Bytes(bytes_tree.new()))
}
