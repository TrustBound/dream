//// Routing guide: a member area under a prefix, and a plain group
////
//// The member controllers take a MemberContext, which holds the signed-in
//// user. The sign-in check is a stand-in that reads an X-User header.

import dream/http/header.{Header, get_header}
import dream/http/request.{type Request, Get, get_param}
import dream/http/response.{type Response, Response, text_response}
import dream/http/status
import dream/router.{type EmptyServices, type Router, route, router, scope}
import gleam/option

pub type Context {
  Context(request_id: String)
}

pub type MemberContext {
  MemberContext(request_id: String, user_name: String)
}

/// Gives the controllers of the member area a MemberContext, or answers 401
pub fn require_member(
  request: Request,
  context: Context,
  services: EmptyServices,
  next: fn(Request, MemberContext, EmptyServices) -> Response,
) -> Response {
  // A stand-in for a real sign-in check, such as a session lookup
  case get_header(request.headers, "X-User") {
    option.Some(user_name) ->
      next(
        request,
        MemberContext(request_id: context.request_id, user_name: user_name),
        services,
      )
    option.None -> text_response(status.unauthorized, "Sign in first")
  }
}

/// Ordinary middleware: it adds a Cache-Control header to the answer
pub fn cache_for_a_minute(
  request: Request,
  context: Context,
  services: EmptyServices,
  next: fn(Request, Context, EmptyServices) -> Response,
) -> Response {
  let response = next(request, context, services)
  Response(..response, headers: [
    Header("Cache-Control", "public, max-age=60"),
    ..response.headers
  ])
}

pub fn show_profile(
  _request: Request,
  context: MemberContext,
  _services: EmptyServices,
) -> Response {
  text_response(status.ok, "Profile of " <> context.user_name)
}

pub fn show_team(
  request: Request,
  context: MemberContext,
  _services: EmptyServices,
) -> Response {
  case get_param(request, "team_id") {
    Ok(team) ->
      text_response(
        status.ok,
        "Team " <> team.value <> " of " <> context.user_name,
      )
    Error(message) -> text_response(status.bad_request, message)
  }
}

pub fn show_about(
  _request: Request,
  _context: Context,
  _services: EmptyServices,
) -> Response {
  text_response(status.ok, "About us")
}

fn member_routes() -> Router(MemberContext, EmptyServices) {
  router()
  |> route(method: Get, path: "/", controller: show_profile, middleware: [])
  |> route(
    method: Get,
    path: "/teams/:team_id",
    controller: show_team,
    middleware: [],
  )
}

fn public_routes() -> Router(Context, EmptyServices) {
  router()
  |> route(method: Get, path: "/about", controller: show_about, middleware: [])
}

pub fn create_router() -> Router(Context, EmptyServices) {
  router()
  |> scope(path: "/members", with: require_member, routes: member_routes())
  |> scope(path: "", with: cache_for_a_minute, routes: public_routes())
}
