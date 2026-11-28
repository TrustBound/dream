import dream/dream
import dream/http/header.{Header}
import dream/http/request.{type Request, Request}
import dream/http/response.{type Response}
import dream/internal/built_in_answer
import dream/router.{type Route, type Router, find_route}
import dream/servers/mist/internal
import dream/servers/mist/request as mist_request
import dream/servers/mist/response as mist_response
import gleam/bit_array
import gleam/erlang/atom
import gleam/http/request as http_request
import gleam/http/response as http_response
import gleam/list
import gleam/option
import gleam/yielder
import mist.{type Connection, type ResponseData}

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
/// - `max_body_size`: Maximum allowed request body size in bytes. A buffered
///   body over it gets `413 Content Too Large` with the plain-text body
///   `Request body too large`, and the controller doesn't run.
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
/// ### Create a Mist handler <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_server_handler_create.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/context.{type AppContext, AppContext}
/// import dream/http/request.{type Request, Get}
/// import dream/http/response.{type Response, text_response}
/// import dream/http/status.{ok}
/// import dream/router.{route, router}
/// import dream/servers/mist/handler
/// import gleam/erlang/process
/// import gleam/otp/actor
/// import gleam/otp/static_supervisor
/// import mist
///
/// fn hello(_request: Request, _context: AppContext, _services: Nil) -> Response {
///   text_response(ok, "Hello")
/// }
///
/// fn with_request_id(_context: AppContext, request_id: String) -> AppContext {
///   AppContext(request_id: request_id)
/// }
///
/// pub fn start(
///   port: Int,
/// ) -> Result(actor.Started(static_supervisor.Supervisor), actor.StartError) {
///   let app_router =
///     router()
///     |> route(method: Get, path: "/", controller: hello, middleware: [])
///   // A Mist handler: each request gets a fresh AppContext, then the router
///   let mist_handler =
///     handler.create(
///       app_router,
///       1_000_000,
///       AppContext(request_id: ""),
///       Nil,
///       with_request_id,
///     )
///   mist.new(mist_handler)
///   |> mist.bind("127.0.0.1")
///   |> mist.port(port)
///   |> mist.start
/// }
///
/// pub fn stop(started: actor.Started(static_supervisor.Supervisor)) -> Nil {
///   process.send_exit(started.pid)
/// }
/// ```
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

      // 405 or 404: answer at once, without reading the body
      option.None ->
        mist_response.convert(
          mist_request,
          built_in_answer.no_route(router, partial_request),
        )
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
    Ok(final_request) ->
      dream.execute_route(
        route,
        final_request,
        params,
        request_context,
        services_instance,
      )
      |> respond_with_route_response(mist_request, _)
    Error(response) -> response
  }
}

fn respond_with_route_response(
  mist_request: http_request.Request(Connection),
  dream_response: Response,
) -> http_response.Response(ResponseData) {
  let upgrade_key = atom.create(internal.upgrade_key)
  let raw_upgrade = internal.get(upgrade_key)
  let maybe_upgrade: option.Option(
    fn(List(#(String, String))) -> http_response.Response(ResponseData),
  ) = internal.unsafe_coerce(raw_upgrade)

  case maybe_upgrade {
    option.Some(perform_upgrade) ->
      upgrade_or_respond(mist_request, dream_response, perform_upgrade)
    option.None -> mist_response.convert(mist_request, dream_response)
  }
}

fn upgrade_or_respond(
  mist_request: http_request.Request(Connection),
  dream_response: Response,
  perform_upgrade: fn(List(#(String, String))) ->
    http_response.Response(ResponseData),
) -> http_response.Response(ResponseData) {
  case dream_response.status {
    200 -> perform_upgrade(extract_dream_headers(dream_response))
    _ -> mist_response.convert(mist_request, dream_response)
  }
}

fn prepare_streaming_request(
  mist_request: http_request.Request(Connection),
  partial_request: Request,
) -> Result(Request, http_response.Response(ResponseData)) {
  case mist.stream(mist_request) {
    Ok(chunk_provider) -> {
      let chunks = yielder.unfold(chunk_provider, stream_unfolder)
      Ok(Request(..partial_request, body: request.Stream(chunks)))
    }
    Error(_) -> Error(unreadable_body_answer(mist_request))
  }
}

/// Reads the next chunk, 64 KB at most. A read that fails gives one
/// `Error(MalformedBody)` item, and the stream ends after it, so a body that
/// stopped early never looks like a stream that ended. `mist.stream` reports
/// every read failure of a body stream as `MalformedBody`.
fn stream_unfolder(
  provider: fn(Int) -> Result(mist.Chunk, mist.ReadError),
) -> yielder.Step(
  Result(BitArray, request.BodyReadError),
  fn(Int) -> Result(mist.Chunk, mist.ReadError),
) {
  case provider(65_536) {
    Ok(mist.Chunk(data, next_provider)) -> yielder.Next(Ok(data), next_provider)
    Ok(mist.Done) -> yielder.Done
    Error(_read_error) -> yielder.Next(Error(request.MalformedBody), body_ended)
  }
}

/// The provider after a failed read: the stream has no more items.
fn body_ended(_size: Int) -> Result(mist.Chunk, mist.ReadError) {
  Ok(mist.Done)
}

/// The HTTP server refuses a body over the limit with `ExcessBody`: a body
/// whose `content-length` is over it before the read, and a chunked or HTTP/2
/// body when it grows over it.
fn prepare_buffered_request(
  mist_request: http_request.Request(Connection),
  partial_request: Request,
  max_body_size: Int,
) -> Result(Request, http_response.Response(ResponseData)) {
  case mist.read_body(mist_request, max_body_limit: max_body_size) {
    Ok(request_with_body) ->
      Ok(
        Request(..partial_request, body: buffered_body(request_with_body.body)),
      )
    Error(mist.ExcessBody) -> Error(too_large_answer(mist_request))
    Error(mist.MalformedBody) -> Error(unreadable_body_answer(mist_request))
  }
}

/// A body that is valid UTF-8 becomes `Text`. Any other body keeps its exact
/// bytes as `Bytes`, so a binary upload is never replaced by an empty string.
fn buffered_body(bytes: BitArray) -> request.RequestBody {
  case bit_array.to_string(bytes) {
    Ok(text) -> request.Text(text)
    Error(Nil) -> request.Bytes(bytes)
  }
}

fn extract_dream_headers(response: Response) -> List(#(String, String)) {
  list.map(response.headers, fn(header) {
    let Header(name, value) = header
    #(name, value)
  })
}

/// 413 Content Too Large (RFC 9110, section 15.5.14): the buffered body is
/// over `max_body_size`.
fn too_large_answer(
  mist_request: http_request.Request(Connection),
) -> http_response.Response(ResponseData) {
  plain_text_answer(mist_request, 413, "Request body too large")
}

/// 400 Bad Request: the body stopped early, or its chunks are malformed.
fn unreadable_body_answer(
  mist_request: http_request.Request(Connection),
) -> http_response.Response(ResponseData) {
  plain_text_answer(mist_request, 400, "Request body could not be read")
}

/// Every answer that the handler gives itself, with no controller, is a short
/// plain-text body.
fn plain_text_answer(
  mist_request: http_request.Request(Connection),
  status: Int,
  text: String,
) -> http_response.Response(ResponseData) {
  mist_response.convert(mist_request, built_in_answer.plain_text(status, text))
}
