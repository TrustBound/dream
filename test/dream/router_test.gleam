import dream/context
import dream/dream

// Status codes moved to dream_json
import dream/http/header.{Header, add_header, get_header}
import dream/http/request.{
  type Method, type Request, Get, Http, Http1, Post, Request,
}
import dream/http/response.{type Response, Response, Text}
import dream/router.{
  type EmptyServices, build_controller_chain, controller, find_route, match_path,
  method, middleware, new as new_route, path, route, router,
}
import gleam/list
import gleam/option
import gleeunit/should

fn create_test_request(method_value: Method, path_value: String) -> Request {
  Request(
    method: method_value,
    protocol: Http,
    version: Http1,
    path: path_value,
    query: "",
    params: [],
    host: option.None,
    port: option.None,
    remote_address: option.None,
    body: "",
    headers: [],
    cookies: [],
    content_type: option.None,
    content_length: option.None,
  )
}

fn test_handler(
  _request: Request,
  _context: context.AppContext,
  _services: EmptyServices,
) -> Response {
  Response(
    status: 200,
    body: Text("test"),
    headers: [Header("Content-Type", "text/plain; charset=utf-8")],
    cookies: [],
    content_type: option.Some("text/plain; charset=utf-8"),
  )
}

pub fn method_with_post_sets_route_method_to_post_test() {
  // Arrange
  let route = path(new_route, "/test")
  let request = create_test_request(Post, "/test")

  // Act
  let updated_route = method(route, Post)
  let router_with_route = router.Router(routes: [updated_route])

  // Assert - verify by using find_route
  case find_route(router_with_route, request) {
    option.Some(_) -> Nil
    option.None -> should.fail()
  }
}

pub fn path_with_valid_path_sets_route_path_test() {
  // Arrange
  let route = new_route
  let path_value = "/users"
  let request = create_test_request(Get, path_value)

  // Act
  let updated_route = path(route, path_value)
  let router_with_route = router.Router(routes: [updated_route])

  // Assert - verify by using find_route
  case find_route(router_with_route, request) {
    option.Some(_) -> Nil
    option.None -> should.fail()
  }
}

pub fn controller_with_valid_controller_sets_route_controller_test() {
  // Arrange
  let route = path(new_route, "/test")
  let request = create_test_request(Get, "/test")
  let context = context.AppContext(request_id: "test-id")
  let services = router.EmptyServices

  // Act
  let updated_route = controller(route, test_handler)
  let router_with_route = router.Router(routes: [updated_route])
  let response =
    dream.route_request(router_with_route, request, context, services)

  // Assert - verify controller works by checking response
  case response {
    Response(_, body, _, _, _) -> {
      case body {
        Text(text) -> text |> should.equal("test")
        _ -> should.fail()
      }
    }
  }
}

pub fn middleware_with_valid_middleware_adds_middleware_to_route_test() {
  // Arrange
  let route = path(new_route, "/test")
  let middleware_fn = fn(
    req: Request,
    _ctx: context.AppContext,
    _svc: EmptyServices,
    next: fn(Request, context.AppContext, EmptyServices) -> Response,
  ) -> Response {
    let response =
      next(req, context.AppContext(request_id: ""), router.EmptyServices)
    case response {
      Response(status, body, headers, cookies, content_type) -> {
        Response(
          status,
          body,
          add_header(headers, "X-Middleware", "applied"),
          cookies,
          content_type,
        )
      }
    }
  }

  // Act
  let updated_route = middleware(route, [middleware_fn])
  let router_with_route = router.Router(routes: [updated_route])
  let request = create_test_request(Get, "/test")
  let context = context.AppContext(request_id: "test-id")
  let services = router.EmptyServices
  let response =
    dream.route_request(router_with_route, request, context, services)

  // Assert - verify middleware was applied by checking header
  case response {
    Response(_, _, headers, _, _) -> {
      case get_header(headers, "X-Middleware") {
        option.Some(value) -> value |> should.equal("applied")
        option.None -> should.fail()
      }
    }
  }
}

pub fn add_route_to_empty_router_creates_router_with_one_route_test() {
  // Arrange
  let empty_router = router

  // Act
  let result =
    route(
      empty_router,
      method: Get,
      path: "/test",
      controller: test_handler,
      middleware: [],
    )
  let request = create_test_request(Get, "/test")
  let context = context.AppContext(request_id: "test-id")
  let services = router.EmptyServices

  // Assert - verify route was added by using route_request
  let response = dream.route_request(result, request, context, services)
  case response {
    Response(_, body, _, _, _) -> {
      case body {
        Text(text) -> text |> should.equal("test")
        _ -> should.fail()
      }
    }
  }
}

pub fn add_route_to_router_with_existing_routes_appends_route_test() {
  // Arrange
  let router_with_routes =
    router
    |> route(
      method: Get,
      path: "/existing",
      controller: test_handler,
      middleware: [],
    )

  // Act
  let result =
    route(
      router_with_routes,
      method: Post,
      path: "/new",
      controller: test_handler,
      middleware: [],
    )

  // Assert - verify both routes work
  let get_request = create_test_request(Get, "/existing")
  let post_request = create_test_request(Post, "/new")
  let context = context.AppContext(request_id: "test-id")
  let services = router.EmptyServices
  let get_response = dream.route_request(result, get_request, context, services)
  let post_response =
    dream.route_request(result, post_request, context, services)

  case get_response {
    Response(_, body, _, _, _) -> {
      case body {
        Text(text) -> text |> should.equal("test")
        _ -> should.fail()
      }
    }
  }
  case post_response {
    Response(_, body, _, _, _) -> {
      case body {
        Text(text) -> text |> should.equal("test")
        _ -> should.fail()
      }
    }
  }
}

pub fn match_path_with_exact_match_returns_empty_params_test() {
  // Arrange
  let pattern = "/users"
  let path_value = "/users"

  // Act
  let result = match_path(pattern, path_value)

  // Assert
  case result {
    option.Some(params) -> {
      list.length(params) |> should.equal(0)
    }
    option.None -> should.fail()
  }
}

pub fn match_path_with_single_parameter_extracts_parameter_test() {
  // Arrange
  let pattern = "/users/:id"
  let path_value = "/users/123"

  // Act
  let result = match_path(pattern, path_value)

  // Assert
  case result {
    option.Some(params) -> {
      list.length(params) |> should.equal(1)
      case params {
        [#(name, value), ..] -> {
          name |> should.equal("id")
          value |> should.equal("123")
        }
        [] -> should.fail()
      }
    }
    option.None -> should.fail()
  }
}

pub fn match_path_with_multiple_parameters_extracts_all_parameters_test() {
  // Arrange
  let pattern = "/users/:id/posts/:post_id"
  let path_value = "/users/123/posts/456"

  // Act
  let result = match_path(pattern, path_value)

  // Assert
  case result {
    option.Some(params) -> {
      list.length(params) |> should.equal(2)
      case params {
        [#(name, value), #(name2, value2), ..] -> {
          name |> should.equal("id")
          value |> should.equal("123")
          name2 |> should.equal("post_id")
          value2 |> should.equal("456")
        }
        _ -> should.fail()
      }
    }
    option.None -> should.fail()
  }
}

pub fn match_path_with_mismatched_length_returns_none_test() {
  // Arrange
  let pattern = "/users/:id"
  let path_value = "/users/123/posts"

  // Act
  let result = match_path(pattern, path_value)

  // Assert
  case result {
    option.Some(_) -> should.fail()
    option.None -> Nil
  }
}

pub fn match_path_with_static_segment_mismatch_returns_none_test() {
  // Arrange
  let pattern = "/users/:id"
  let path_value = "/posts/123"

  // Act
  let result = match_path(pattern, path_value)

  // Assert
  case result {
    option.Some(_) -> should.fail()
    option.None -> Nil
  }
}

pub fn find_route_with_matching_route_returns_route_and_params_test() {
  // Arrange
  let test_route =
    router.Route(
      method: Get,
      path: "/users/:id",
      controller: test_handler,
      middleware: [],
    )
  let test_router = router.Router(routes: [test_route])
  let request = create_test_request(Get, "/users/123")

  // Act
  let result = find_route(test_router, request)

  // Assert
  case result {
    option.Some(#(_route, params)) -> {
      list.length(params) |> should.equal(1)
      case params {
        [#(name, value), ..] -> {
          name |> should.equal("id")
          value |> should.equal("123")
        }
        [] -> should.fail()
      }
    }
    option.None -> should.fail()
  }
}

pub fn find_route_with_method_mismatch_returns_none_test() {
  // Arrange
  let test_route =
    router.Route(
      method: Post,
      path: "/users/:id",
      controller: test_handler,
      middleware: [],
    )
  let test_router = router.Router(routes: [test_route])
  let request = create_test_request(Get, "/users/123")

  // Act
  let result = find_route(test_router, request)

  // Assert
  case result {
    option.Some(_) -> should.fail()
    option.None -> Nil
  }
}

pub fn find_route_with_no_matching_route_returns_none_test() {
  // Arrange
  let test_route =
    router.Route(
      method: Get,
      path: "/users/:id",
      controller: test_handler,
      middleware: [],
    )
  let test_router = router.Router(routes: [test_route])
  let request = create_test_request(Get, "/posts/123")

  // Act
  let result = find_route(test_router, request)

  // Assert
  case result {
    option.Some(_) -> should.fail()
    option.None -> Nil
  }
}

pub fn build_controller_chain_with_no_middleware_returns_controller_test() {
  // Arrange
  let final_controller = test_handler
  let request = create_test_request(Get, "/")
  let context = context.AppContext(request_id: "test-id")
  let services = router.EmptyServices

  // Act
  let chain = build_controller_chain([], final_controller)
  let response = chain(request, context, services)

  // Assert
  case response {
    Response(_, body, _, _, _) -> {
      case body {
        Text(text) -> text |> should.equal("test")
        _ -> should.fail()
      }
    }
  }
}

pub fn build_controller_chain_with_middleware_wraps_controller_test() {
  // Arrange
  let final_controller = test_handler
  let middleware_fn = fn(
    req: Request,
    ctx: context.AppContext,
    svc: EmptyServices,
    next: fn(Request, context.AppContext, EmptyServices) -> Response,
  ) -> Response {
    let response = next(req, ctx, svc)
    case response {
      Response(status, body, headers, cookies, content_type) -> {
        let modified_body = case body {
          Text(text) -> Text(text <> "-modified")
          _ -> body
        }
        Response(status, modified_body, headers, cookies, content_type)
      }
    }
  }
  let middleware_list = [router.Middleware(middleware_fn)]
  let request = create_test_request(Get, "/")
  let context = context.AppContext(request_id: "test-id")
  let services = router.EmptyServices

  // Act
  let chain = build_controller_chain(middleware_list, final_controller)
  let response = chain(request, context, services)

  // Assert
  case response {
    Response(_, body, _, _, _) -> {
      case body {
        Text(text) -> text |> should.equal("test-modified")
        _ -> should.fail()
      }
    }
  }
}

pub fn build_controller_chain_with_multiple_middleware_executes_in_order_test() {
  // Arrange
  let final_controller = test_handler
  let middleware1 =
    router.Middleware(
      fn(
        req: Request,
        ctx: context.AppContext,
        svc: EmptyServices,
        next: fn(Request, context.AppContext, EmptyServices) -> Response,
      ) -> Response {
        let response = next(req, ctx, svc)
        case response {
          Response(status, body, headers, cookies, content_type) -> {
            let modified_body = case body {
              Text(text) -> Text(text <> "-m1")
              _ -> body
            }
            Response(status, modified_body, headers, cookies, content_type)
          }
        }
      },
    )
  let middleware2 =
    router.Middleware(
      fn(
        req: Request,
        ctx: context.AppContext,
        svc: EmptyServices,
        next: fn(Request, context.AppContext, EmptyServices) -> Response,
      ) -> Response {
        let response = next(req, ctx, svc)
        case response {
          Response(status, body, headers, cookies, content_type) -> {
            let modified_body = case body {
              Text(text) -> Text(text <> "-m2")
              _ -> body
            }
            Response(status, modified_body, headers, cookies, content_type)
          }
        }
      },
    )
  let request = create_test_request(Get, "/")
  let context = context.AppContext(request_id: "test-id")
  let services = router.EmptyServices

  // Act
  let chain =
    build_controller_chain([middleware1, middleware2], final_controller)
  let response = chain(request, context, services)

  // Assert
  case response {
    Response(_, body, _, _, _) -> {
      case body {
        Text(text) -> text |> should.equal("test-m2-m1")
        _ -> should.fail()
      }
    }
  }
}

// ===== Single Wildcard Tests =====

pub fn match_path_with_named_single_wildcard_captures_segment_test() {
  // Arrange
  let pattern = "/files/*filename"
  let path_value = "/files/document.pdf"

  // Act
  let result = match_path(pattern, path_value)

  // Assert
  case result {
    option.Some(params) -> {
      list.length(params) |> should.equal(1)
      case params {
        [#(name, value), ..] -> {
          name |> should.equal("filename")
          value |> should.equal("document.pdf")
        }
        [] -> should.fail()
      }
    }
    option.None -> should.fail()
  }
}

pub fn match_path_with_anonymous_single_wildcard_matches_but_no_capture_test() {
  // Arrange
  let pattern = "/health/*/check"
  let path_value = "/health/api/check"

  // Act
  let result = match_path(pattern, path_value)

  // Assert
  case result {
    option.Some(params) -> {
      list.length(params) |> should.equal(0)
    }
    option.None -> should.fail()
  }
}

pub fn match_path_with_single_wildcard_in_middle_extracts_correctly_test() {
  // Arrange
  let pattern = "/users/:id/files/*filename"
  let path_value = "/users/123/files/report.pdf"

  // Act
  let result = match_path(pattern, path_value)

  // Assert
  case result {
    option.Some(params) -> {
      list.length(params) |> should.equal(2)
      case params {
        [#(name1, value1), #(name2, value2), ..] -> {
          name1 |> should.equal("id")
          value1 |> should.equal("123")
          name2 |> should.equal("filename")
          value2 |> should.equal("report.pdf")
        }
        _ -> should.fail()
      }
    }
    option.None -> should.fail()
  }
}

pub fn match_path_with_multiple_single_wildcards_test() {
  // Arrange
  let pattern = "/files/*category/*filename"
  let path_value = "/files/documents/report.pdf"

  // Act
  let result = match_path(pattern, path_value)

  // Assert
  case result {
    option.Some(params) -> {
      list.length(params) |> should.equal(2)
      case params {
        [#(name1, value1), #(name2, value2), ..] -> {
          name1 |> should.equal("category")
          value1 |> should.equal("documents")
          name2 |> should.equal("filename")
          value2 |> should.equal("report.pdf")
        }
        _ -> should.fail()
      }
    }
    option.None -> should.fail()
  }
}

// ===== Multi Wildcard Tests =====

pub fn match_path_with_named_multi_wildcard_at_end_captures_all_test() {
  // Arrange
  let pattern = "/static/**filepath"
  let path_value = "/static/css/main.css"

  // Act
  let result = match_path(pattern, path_value)

  // Assert
  case result {
    option.Some(params) -> {
      list.length(params) |> should.equal(1)
      case params {
        [#(name, value), ..] -> {
          name |> should.equal("filepath")
          value |> should.equal("css/main.css")
        }
        [] -> should.fail()
      }
    }
    option.None -> should.fail()
  }
}

pub fn match_path_with_multi_wildcard_deep_path_test() {
  // Arrange
  let pattern = "/assets/**path"
  let path_value = "/assets/v1/images/photos/2024/photo.jpg"

  // Act
  let result = match_path(pattern, path_value)

  // Assert
  case result {
    option.Some(params) -> {
      list.length(params) |> should.equal(1)
      case params {
        [#(name, value), ..] -> {
          name |> should.equal("path")
          value |> should.equal("v1/images/photos/2024/photo.jpg")
        }
        [] -> should.fail()
      }
    }
    option.None -> should.fail()
  }
}

pub fn match_path_with_multi_wildcard_in_middle_matches_correctly_test() {
  // Arrange
  let pattern = "/api/**/metadata"
  let path_value = "/api/v1/users/123/metadata"

  // Act
  let result = match_path(pattern, path_value)

  // Assert
  case result {
    option.Some(_) -> Nil
    option.None -> should.fail()
  }
}

pub fn match_path_with_anonymous_multi_wildcard_matches_test() {
  // Arrange
  let pattern = "/api/**"
  let path_value = "/api/v1/users/123/profile"

  // Act
  let result = match_path(pattern, path_value)

  // Assert
  case result {
    option.Some(params) -> {
      list.length(params) |> should.equal(0)
    }
    option.None -> should.fail()
  }
}

pub fn match_path_with_multi_wildcard_empty_path_returns_empty_string_test() {
  // Arrange
  let pattern = "/api/**rest"
  let path_value = "/api"

  // Act
  let result = match_path(pattern, path_value)

  // Assert
  case result {
    option.Some(params) -> {
      list.length(params) |> should.equal(1)
      case params {
        [#(name, value), ..] -> {
          name |> should.equal("rest")
          value |> should.equal("")
        }
        [] -> should.fail()
      }
    }
    option.None -> should.fail()
  }
}

pub fn match_path_with_multi_wildcard_and_static_suffix_test() {
  // Arrange
  let pattern = "/files/**/download"
  let path_value = "/files/2024/reports/annual/download"

  // Act
  let result = match_path(pattern, path_value)

  // Assert
  case result {
    option.Some(_) -> Nil
    option.None -> should.fail()
  }
}

// ===== Extension Matching Tests =====

pub fn match_path_with_extension_pattern_matches_correct_files_test() {
  // Arrange
  let pattern = "/images/*.jpg"
  let path_value = "/images/photo.jpg"

  // Act
  let result = match_path(pattern, path_value)

  // Assert
  case result {
    option.Some(_) -> Nil
    option.None -> should.fail()
  }
}

pub fn match_path_with_extension_pattern_rejects_wrong_extension_test() {
  // Arrange
  let pattern = "/images/*.jpg"
  let path_value = "/images/photo.png"

  // Act
  let result = match_path(pattern, path_value)

  // Assert
  case result {
    option.Some(_) -> should.fail()
    option.None -> Nil
  }
}

pub fn match_path_with_brace_expansion_matches_multiple_extensions_test() {
  // Arrange
  let pattern = "/images/*.{jpg,png,gif}"
  let path_jpg = "/images/photo.jpg"
  let path_png = "/images/logo.png"
  let path_gif = "/images/animation.gif"

  // Act
  let result_jpg = match_path(pattern, path_jpg)
  let result_png = match_path(pattern, path_png)
  let result_gif = match_path(pattern, path_gif)

  // Assert
  case result_jpg {
    option.Some(_) -> Nil
    option.None -> should.fail()
  }
  case result_png {
    option.Some(_) -> Nil
    option.None -> should.fail()
  }
  case result_gif {
    option.Some(_) -> Nil
    option.None -> should.fail()
  }
}

pub fn match_path_with_brace_expansion_rejects_unlisted_extension_test() {
  // Arrange
  let pattern = "/images/*.{jpg,png}"
  let path_value = "/images/document.pdf"

  // Act
  let result = match_path(pattern, path_value)

  // Assert
  case result {
    option.Some(_) -> should.fail()
    option.None -> Nil
  }
}

pub fn match_path_with_brace_expansion_with_spaces_test() {
  // Arrange
  let pattern = "/files/*.{pdf, doc, txt}"
  let path_value = "/files/report.pdf"

  // Act
  let result = match_path(pattern, path_value)

  // Assert
  case result {
    option.Some(_) -> Nil
    option.None -> should.fail()
  }
}

// ===== Combined Patterns Tests =====

pub fn match_path_with_param_and_wildcard_extracts_both_test() {
  // Arrange
  let pattern = "/users/:id/files/*filename"
  let path_value = "/users/456/files/document.pdf"

  // Act
  let result = match_path(pattern, path_value)

  // Assert
  case result {
    option.Some(params) -> {
      list.length(params) |> should.equal(2)
      case params {
        [#(name1, value1), #(name2, value2), ..] -> {
          name1 |> should.equal("id")
          value1 |> should.equal("456")
          name2 |> should.equal("filename")
          value2 |> should.equal("document.pdf")
        }
        _ -> should.fail()
      }
    }
    option.None -> should.fail()
  }
}

pub fn match_path_with_param_and_multi_wildcard_test() {
  // Arrange
  let pattern = "/api/:version/**endpoint"
  let path_value = "/api/v1/users/123/profile"

  // Act
  let result = match_path(pattern, path_value)

  // Assert
  case result {
    option.Some(params) -> {
      list.length(params) |> should.equal(2)
      case params {
        [#(name1, value1), #(name2, value2), ..] -> {
          name1 |> should.equal("version")
          value1 |> should.equal("v1")
          name2 |> should.equal("endpoint")
          value2 |> should.equal("users/123/profile")
        }
        _ -> should.fail()
      }
    }
    option.None -> should.fail()
  }
}

// ===== Edge Cases =====

pub fn match_path_with_wildcard_only_pattern_matches_anything_test() {
  // Arrange
  let pattern = "/**"
  let path_value = "/any/path/at/all"

  // Act
  let result = match_path(pattern, path_value)

  // Assert
  case result {
    option.Some(_) -> Nil
    option.None -> should.fail()
  }
}

pub fn match_path_single_wildcard_does_not_match_multiple_segments_test() {
  // Arrange
  let pattern = "/files/*/download"
  let path_value = "/files/reports/2024/download"

  // Act
  let result = match_path(pattern, path_value)

  // Assert
  case result {
    option.Some(_) -> should.fail()
    option.None -> Nil
  }
}

pub fn match_path_multi_wildcard_matches_zero_segments_test() {
  // Arrange
  let pattern = "/api/**/endpoint"
  let path_value = "/api/endpoint"

  // Act
  let result = match_path(pattern, path_value)

  // Assert
  case result {
    option.Some(_) -> Nil
    option.None -> should.fail()
  }
}

pub fn match_path_with_multi_wildcard_and_extension_pattern_test() {
  // Arrange
  let pattern = "/images/**/*.{jpg,png,svg}"
  let path_value = "/images/cat.svg"

  // Act
  let result = match_path(pattern, path_value)

  // Assert - Just verify it matches
  case result {
    option.Some(_) -> Nil
    option.None -> should.fail()
  }
}

// Verify all pattern types used in static example
pub fn match_path_single_named_wildcard_simple_test() {
  let pattern = "/files/*filename"
  let path = "/files/doc.pdf"

  case match_path(pattern, path) {
    option.Some(params) -> {
      case params {
        [#("filename", "doc.pdf")] -> Nil
        _ -> should.fail()
      }
    }
    option.None -> should.fail()
  }
}

pub fn match_path_anonymous_single_wildcard_with_suffix_test() {
  let pattern = "/health/*/status"
  let path = "/health/api/status"

  case match_path(pattern, path) {
    option.Some(params) -> {
      list.length(params) |> should.equal(0)
    }
    option.None -> should.fail()
  }
}

pub fn match_path_extension_css_only_test() {
  let pattern = "/css/*.css"
  let path = "/css/main.css"

  case match_path(pattern, path) {
    option.Some(_) -> Nil
    option.None -> should.fail()
  }
}

pub fn match_path_brace_expansion_image_test() {
  let pattern = "/images/*.{jpg,png,gif,svg}"
  let path = "/images/cat.svg"

  case match_path(pattern, path) {
    option.Some(_) -> Nil
    option.None -> should.fail()
  }
}
