//// Naming conventions: Modification
////
//// `set_{noun}` replaces a value, `add_{noun}` adds one and keeps the
//// others, and `remove_{noun}` takes one out. Each returns a new value.

import dream/http.{type Request, ok, text_response}
import dream/http/cookie.{type Cookie}
import dream/http/header.{type Header}
import dream/http/request.{Get}
import dream/router

pub fn set_cache_and_theme(request: Request) -> #(List(Header), List(Cookie)) {
  let headers = header.set_header(request.headers, "Cache-Control", "no-store")
  let cookies =
    cookie.set_cookie(request.cookies, cookie.simple_cookie("theme", "dark"))
  #(headers, cookies)
}

pub fn add_link_and_route(request: Request) {
  let headers =
    header.add_header(request.headers, "Link", "</app.css>; rel=preload")
  let app_router =
    router.router()
    |> router.route(method: Get, path: "/", controller: index, middleware: [])
  #(headers, app_router)
}

pub fn remove_tracking(request: Request) -> #(List(Header), List(Cookie)) {
  let headers = header.remove_header(request.headers, "X-Tracking-Id")
  let cookies = cookie.remove_cookie(request.cookies, "tracking")
  #(headers, cookies)
}

fn index(_request, _context, _services) {
  text_response(ok, "Home")
}
