import dream/core/context.{type AppContext, new_context}
import dream/core/dream
import dream/core/http/statuses.{ok_status}
import dream/core/http/transaction
import dream/core/router.{
  add_route, build_handler_chain, find_route, handler, match_path, method,
  middleware, new as new_route, path, router,
}
import gleam/list
import gleam/option
import gleeunit/should

fn create_test_request(
  method_value: transaction.Method,
  path_value: String,
) -> transaction.Request(AppContext) {
  transaction.Request(
    method: method_value,
    protocol: transaction.Http,
    version: transaction.Http1,
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
    context: new_context("test-id"),
  )
}

fn test_handler(
  _request: transaction.Request(AppContext),
) -> transaction.Response {
  transaction.text_response(ok_status(), "test")
}

pub fn method_with_post_sets_route_method_to_post_test() {
  // Arrange
  let route = path(new_route, "/test")
  let request = create_test_request(transaction.Post, "/test")

  // Act
  let updated_route = method(route, transaction.Post)
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
  let request = create_test_request(transaction.Get, path_value)

  // Act
  let updated_route = path(route, path_value)
  let router_with_route = router.Router(routes: [updated_route])

  // Assert - verify by using find_route
  case find_route(router_with_route, request) {
    option.Some(_) -> Nil
    option.None -> should.fail()
  }
}

pub fn handler_with_valid_handler_sets_route_handler_test() {
  // Arrange
  let route = path(new_route, "/test")
  let request = create_test_request(transaction.Get, "/test")

  // Act
  let updated_route = handler(route, test_handler)
  let router_with_route = router.Router(routes: [updated_route])
  let response = dream.route_request(router_with_route, request)

  // Assert - verify handler works by checking response
  case response {
    transaction.Response(_, body, _, _, _, _) -> {
      body |> should.equal("test")
    }
  }
}

pub fn middleware_with_valid_middleware_adds_middleware_to_route_test() {
  // Arrange
  let route = path(new_route, "/test")
  let middleware_fn = fn(
    req: transaction.Request(AppContext),
    next: fn(transaction.Request(AppContext)) -> transaction.Response,
  ) -> transaction.Response {
    let response = next(req)
    case response {
      transaction.Response(
        status,
        body,
        headers,
        cookies,
        content_type,
        content_length,
      ) -> {
        transaction.Response(
          status,
          body,
          transaction.add_header(headers, "X-Middleware", "applied"),
          cookies,
          content_type,
          content_length,
        )
      }
    }
  }

  // Act
  let updated_route = middleware(route, [middleware_fn])
  let router_with_route = router.Router(routes: [updated_route])
  let request = create_test_request(transaction.Get, "/test")
  let response = dream.route_request(router_with_route, request)

  // Assert - verify middleware was applied by checking header
  case response {
    transaction.Response(_, _, headers, _, _, _) -> {
      case transaction.get_header(headers, "X-Middleware") {
        option.Some(value) -> value |> should.equal("applied")
        option.None -> should.fail()
      }
    }
  }
}

pub fn add_route_to_empty_router_creates_router_with_one_route_test() {
  // Arrange
  let empty_router = router
  let test_route =
    router.Route(
      method: transaction.Get,
      path: "/test",
      handler: test_handler,
      middleware: [],
    )

  // Act
  let result = add_route(empty_router, test_route)
  let request = create_test_request(transaction.Get, "/test")

  // Assert - verify route was added by using route_request
  let response = dream.route_request(result, request)
  case response {
    transaction.Response(_, body, _, _, _, _) -> {
      body |> should.equal("test")
    }
  }
}

pub fn add_route_to_router_with_existing_routes_appends_route_test() {
  // Arrange
  let existing_route =
    router.Route(
      method: transaction.Get,
      path: "/existing",
      handler: test_handler,
      middleware: [],
    )
  let router_with_routes = router.Router(routes: [existing_route])
  let new_route =
    router.Route(
      method: transaction.Post,
      path: "/new",
      handler: test_handler,
      middleware: [],
    )

  // Act
  let result = add_route(router_with_routes, new_route)

  // Assert - verify both routes work
  let get_request = create_test_request(transaction.Get, "/existing")
  let post_request = create_test_request(transaction.Post, "/new")
  let get_response = dream.route_request(result, get_request)
  let post_response = dream.route_request(result, post_request)

  case get_response {
    transaction.Response(_, body, _, _, _, _) -> {
      body |> should.equal("test")
    }
  }
  case post_response {
    transaction.Response(_, body, _, _, _, _) -> {
      body |> should.equal("test")
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
      method: transaction.Get,
      path: "/users/:id",
      handler: test_handler,
      middleware: [],
    )
  let test_router = router.Router(routes: [test_route])
  let request = create_test_request(transaction.Get, "/users/123")

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
      method: transaction.Post,
      path: "/users/:id",
      handler: test_handler,
      middleware: [],
    )
  let test_router = router.Router(routes: [test_route])
  let request = create_test_request(transaction.Get, "/users/123")

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
      method: transaction.Get,
      path: "/users/:id",
      handler: test_handler,
      middleware: [],
    )
  let test_router = router.Router(routes: [test_route])
  let request = create_test_request(transaction.Get, "/posts/123")

  // Act
  let result = find_route(test_router, request)

  // Assert
  case result {
    option.Some(_) -> should.fail()
    option.None -> Nil
  }
}

pub fn build_handler_chain_with_no_middleware_returns_handler_test() {
  // Arrange
  let final_handler = test_handler
  let request = create_test_request(transaction.Get, "/")

  // Act
  let chain = build_handler_chain([], final_handler)
  let response = chain(request)

  // Assert
  case response {
    transaction.Response(_, body, _, _, _, _) -> {
      body |> should.equal("test")
    }
  }
}

pub fn build_handler_chain_with_middleware_wraps_handler_test() {
  // Arrange
  let final_handler = test_handler
  let middleware_fn = fn(
    req: transaction.Request(AppContext),
    next: fn(transaction.Request(AppContext)) -> transaction.Response,
  ) -> transaction.Response {
    let response = next(req)
    case response {
      transaction.Response(
        status,
        body,
        headers,
        cookies,
        content_type,
        content_length,
      ) -> {
        transaction.Response(
          status,
          body <> "-modified",
          headers,
          cookies,
          content_type,
          content_length,
        )
      }
    }
  }
  let middleware_list = [router.Middleware(middleware_fn)]
  let request = create_test_request(transaction.Get, "/")

  // Act
  let chain = build_handler_chain(middleware_list, final_handler)
  let response = chain(request)

  // Assert
  case response {
    transaction.Response(_, body, _, _, _, _) -> {
      body |> should.equal("test-modified")
    }
  }
}

pub fn build_handler_chain_with_multiple_middleware_executes_in_order_test() {
  // Arrange
  let final_handler = test_handler
  let middleware1 =
    router.Middleware(
      fn(
        req: transaction.Request(AppContext),
        next: fn(transaction.Request(AppContext)) -> transaction.Response,
      ) -> transaction.Response {
        let response = next(req)
        case response {
          transaction.Response(
            status,
            body,
            headers,
            cookies,
            content_type,
            content_length,
          ) -> {
            transaction.Response(
              status,
              body <> "-m1",
              headers,
              cookies,
              content_type,
              content_length,
            )
          }
        }
      },
    )
  let middleware2 =
    router.Middleware(
      fn(
        req: transaction.Request(AppContext),
        next: fn(transaction.Request(AppContext)) -> transaction.Response,
      ) -> transaction.Response {
        let response = next(req)
        case response {
          transaction.Response(
            status,
            body,
            headers,
            cookies,
            content_type,
            content_length,
          ) -> {
            transaction.Response(
              status,
              body <> "-m2",
              headers,
              cookies,
              content_type,
              content_length,
            )
          }
        }
      },
    )
  let request = create_test_request(transaction.Get, "/")

  // Act
  let chain = build_handler_chain([middleware1, middleware2], final_handler)
  let response = chain(request)

  // Assert
  case response {
    transaction.Response(_, body, _, _, _, _) -> {
      body |> should.equal("test-m2-m1")
    }
  }
}
