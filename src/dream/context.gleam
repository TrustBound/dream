//// Request context for your application
////
//// Context holds per-request data that changes with every request—user authentication,
//// session info, request IDs, etc. It's passed to every middleware and controller.
////
//// ## The Default Context
////
//// Dream provides `AppContext` with just a `request_id` field. It's fine for simple apps,
//// but most applications will want their own context type.
////
//// ## Custom Context
////
//// Define your own context type to hold whatever per-request data you need:
////
//// ```gleam
//// pub type MyContext {
////   MyContext(
////     request_id: String,
////     user: Option(User),
////     session: Session,
////     permissions: List(String),
////   )
//// }
//// ```
////
//// Then pass it to your server:
////
//// ```gleam
//// dream.new()
//// |> dream.context(MyContext(
////      request_id: "",
////      user: None,
////      session: empty_session(),
////      permissions: []
////    ))
//// |> dream.services(my_services)
//// |> dream.router(my_router)
//// |> dream.listen(3000)
//// ```
////
//// ## Enriching Context in Middleware
////
//// Middleware can update the context as requests flow through:
////
//// ```gleam
//// pub fn auth_middleware(request, context, services, next) {
////   let token_result = extract_token(request)
////   
////   case token_result {
////     Ok(token) -> handle_valid_token(token, request, context, services, next)
////     Error(_) -> unauthorized_response()
////   }
//// }
//// 
//// fn handle_valid_token(token, request, context, services, next) {
////   let user = verify_token(services.db, token)
////   let new_context = MyContext(..context, user: Some(user))
////   next(request, new_context, services)
//// }
//// ```
////
//// The type system ensures your controllers receive the right context type.

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
