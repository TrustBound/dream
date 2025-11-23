//// Request context for your application
////
//// Context holds per-request data that changes with every request—user authentication,
//// session info, request IDs, etc. It's passed to every middleware and controller.
////
//// ## Empty Context
////
//// For simple applications that don't need per-request context, Dream defaults to `EmptyContext`.
//// You don't need to set it explicitly:
////
//// ```gleam
//// import dream/servers/mist/server.{listen, router}
//// 
//// server.new()
//// |> router(my_router)
//// |> listen(3000)
//// ```
////
//// If you need to explicitly set EmptyContext (e.g., replacing a previously set context):
////
//// ```gleam
//// import dream/context.{type EmptyContext, EmptyContext}
//// import dream/servers/mist/server.{context, listen, router}
//// 
//// server.new()
//// |> context(EmptyContext)
//// |> router(my_router)
//// |> listen(3000)
//// ```
////
//// ## App Context
////
//// Dream also provides `AppContext` with a `request_id` field. Use this if you want
//// basic request tracking but don't need custom context yet:
////
//// ```gleam
//// import dream/context.{type AppContext, AppContext}
//// import dream/servers/mist/server.{context, listen, router}
//// 
//// server.new()
//// |> context(AppContext(request_id: ""))
//// |> router(my_router)
//// |> listen(3000)
//// ```
////
//// Most applications will eventually want their own custom context type.
////
//// ## Custom Context
////
//// Define your own context type to hold whatever per-request data you need:
////
//// ```gleam
//// import gleam/option.{None}
//// 
//// pub type MyContext {
////   MyContext(
////     request_id: String,
////     user: option.Option(User),
////     session: Session,
////     permissions: List(String),
////   )
//// }
//// ```
////
//// Then pass it to your server:
////
//// ```gleam
//// import dream/servers/mist/server.{context, listen, router, services}
//// 
//// server.new()
//// |> context(MyContext(
////      request_id: "",
////      user: None,
////      session: empty_session(),
////      permissions: [],
////    ))
//// |> services(my_services)
//// |> router(my_router)
//// |> listen(3000)
//// ```
////
//// ## Enriching Context in Middleware
////
//// Middleware can update the context as requests flow through:
////
//// ```gleam
//// import dream/http/request.{type Request}
//// import dream/http/response.{type Response, text_response}
//// import dream/http/status.{unauthorized}
//// import gleam/option.{Some}
//// 
//// pub fn auth_middleware(
////   request: Request,
////   context: MyContext,
////   services: Services,
////   next: fn(Request, MyContext, Services) -> Response,
//// ) -> Response {
////   case extract_token(request) {
////     Ok(token) -> {
////       let user = verify_token(services.db, token)
////       let new_context = MyContext(..context, user: Some(user))
////       next(request, new_context, services)
////     }
////     Error(_) -> text_response(unauthorized, "Authentication required")
////   }
//// }
//// ```
////
//// The type system ensures your controllers receive the right context type.

/// Placeholder for when you don't need context
///
/// Use this when you're building a simple application that doesn't need per-request
/// context like user sessions or authentication. For anything more complex, define
/// your own context type.
pub type EmptyContext {
  EmptyContext
}

/// Default context with just a request ID
///
/// Use this for simple applications or replace it with your own context type.
/// Most real applications will want custom context for user data, sessions, etc.
pub type AppContext {
  AppContext(request_id: String)
}

/// Create a new AppContext
///
/// Helper for creating the default context. If you're using a custom context,
/// you'll create it directly without this function.
pub fn new_context(request_id: String) -> AppContext {
  AppContext(request_id: request_id)
}
