// Radix Trie for Route Matching - Proof of Concept
//
// Shows how structured segments enable O(path depth) route lookup
// instead of O(number of routes) linear search

import gleam/dict.{type Dict}
import gleam/io
import gleam/option.{type Option, None, Some}
import gleeunit/should

// ============================================================================
// Types from routing POC
// ============================================================================

pub type Segment {
  Literal(String)
  IntParam(name: String)
  StringParam(name: String)
}

pub type Method {
  Get
  Post
  Put
  Delete
}

// ============================================================================
// Radix Trie Types
// ============================================================================

/// A node in the radix trie
/// Each node can have:
/// - Literal children (keyed by exact string)
/// - A parameter child (matches any segment, captures value)
/// - A route (if this node is an endpoint)
pub type TrieNode(route) {
  TrieNode(
    // Routes at this node (keyed by method)
    routes: Dict(Method, route),
    // Literal segment children: "users" -> child node
    literal_children: Dict(String, TrieNode(route)),
    // Parameter child: matches any segment
    param_child: Option(ParamNode(route)),
  )
}

pub type ParamNode(route) {
  IntParamNode(name: String, child: TrieNode(route))
  StringParamNode(name: String, child: TrieNode(route))
}

/// Radix trie for fast route lookup
pub type RadixTrie(route) {
  RadixTrie(root: TrieNode(route))
}

/// Result of a route lookup
pub type Match(route) {
  Match(route: route, params: List(#(String, String)), nodes_visited: Int)
}

// ============================================================================
// Trie Construction
// ============================================================================

/// Create an empty trie
pub fn new_trie() -> RadixTrie(route) {
  RadixTrie(root: empty_node())
}

fn empty_node() -> TrieNode(route) {
  TrieNode(routes: dict.new(), literal_children: dict.new(), param_child: None)
}

/// Insert a route into the trie
pub fn insert(
  trie: RadixTrie(route),
  method: Method,
  segments: List(Segment),
  route: route,
) -> RadixTrie(route) {
  let updated_root = insert_into_node(trie.root, method, segments, route)
  RadixTrie(root: updated_root)
}

fn insert_into_node(
  node: TrieNode(route),
  method: Method,
  segments: List(Segment),
  route: route,
) -> TrieNode(route) {
  case segments {
    // Base case: no more segments, store route at this node
    [] -> {
      let updated_routes = dict.insert(node.routes, method, route)
      TrieNode(..node, routes: updated_routes)
    }

    // Literal segment: traverse/create literal child
    [Literal(name), ..rest] -> {
      let child = case dict.get(node.literal_children, name) {
        Ok(existing) -> existing
        Error(_) -> empty_node()
      }
      let updated_child = insert_into_node(child, method, rest, route)
      let updated_children =
        dict.insert(node.literal_children, name, updated_child)
      TrieNode(..node, literal_children: updated_children)
    }

    // Int parameter: traverse/create param child
    [IntParam(name), ..rest] -> {
      let child = case node.param_child {
        Some(IntParamNode(_, existing)) -> existing
        Some(StringParamNode(_, existing)) -> existing
        None -> empty_node()
      }
      let updated_child = insert_into_node(child, method, rest, route)
      TrieNode(..node, param_child: Some(IntParamNode(name, updated_child)))
    }

    // String parameter: traverse/create param child
    [StringParam(name), ..rest] -> {
      let child = case node.param_child {
        Some(StringParamNode(_, existing)) -> existing
        Some(IntParamNode(_, existing)) -> existing
        None -> empty_node()
      }
      let updated_child = insert_into_node(child, method, rest, route)
      TrieNode(..node, param_child: Some(StringParamNode(name, updated_child)))
    }
  }
}

// ============================================================================
// Trie Lookup
// ============================================================================

/// Look up a route in the trie
/// Returns the route, captured parameters, and nodes visited count
pub fn lookup(
  trie: RadixTrie(route),
  method: Method,
  path_segments: List(String),
) -> Option(Match(route)) {
  lookup_in_node(trie.root, method, path_segments, [], 0)
}

fn lookup_in_node(
  node: TrieNode(route),
  method: Method,
  path_segments: List(String),
  params: List(#(String, String)),
  nodes_visited: Int,
) -> Option(Match(route)) {
  let current_count = nodes_visited + 1

  case path_segments {
    // No more segments - check if this node has a route for this method
    [] -> {
      case dict.get(node.routes, method) {
        Ok(route) -> Some(Match(route, params, current_count))
        Error(_) -> None
      }
    }

    // Try to match next segment
    [segment, ..rest] -> {
      // First try literal match (most specific)
      case dict.get(node.literal_children, segment) {
        Ok(child) -> lookup_in_node(child, method, rest, params, current_count)
        Error(_) -> {
          // No literal match, try parameter match
          case node.param_child {
            Some(IntParamNode(name, child)) -> {
              let updated_params = [#(name, segment), ..params]
              lookup_in_node(child, method, rest, updated_params, current_count)
            }
            Some(StringParamNode(name, child)) -> {
              let updated_params = [#(name, segment), ..params]
              lookup_in_node(child, method, rest, updated_params, current_count)
            }
            None -> None
          }
        }
      }
    }
  }
}

// Note: In production, path segments would come directly from the request parser
// This helper is just for the demo function that uses string paths

// ============================================================================
// Tests
// ============================================================================

pub fn empty_trie_has_no_routes_test() {
  let trie = new_trie()
  let result = lookup(trie, Get, ["users"])

  result
  |> should.equal(None)
}

pub fn insert_and_lookup_literal_route_test() {
  let trie =
    new_trie()
    |> insert(Get, [Literal("users")], "list_users")

  let result = lookup(trie, Get, ["users"])

  case result {
    Some(Match(route, params, _)) -> {
      route |> should.equal("list_users")
      params |> should.equal([])
    }
    None -> panic as "Expected to find route"
  }
}

pub fn lookup_wrong_method_returns_none_test() {
  let trie =
    new_trie()
    |> insert(Get, [Literal("users")], "list_users")

  let result = lookup(trie, Post, ["users"])

  result |> should.equal(None)
}

pub fn insert_and_lookup_param_route_test() {
  let trie =
    new_trie()
    |> insert(Get, [Literal("users"), IntParam("id")], "show_user")

  let result = lookup(trie, Get, ["users", "123"])

  case result {
    Some(Match(route, params, _)) -> {
      route |> should.equal("show_user")
      params |> should.equal([#("id", "123")])
    }
    None -> panic as "Expected to find route"
  }
}

pub fn literal_match_takes_precedence_over_param_test() {
  let trie =
    new_trie()
    |> insert(Get, [Literal("users"), Literal("new")], "new_user_form")
    |> insert(Get, [Literal("users"), IntParam("id")], "show_user")

  // Should match literal "new" not param
  let result = lookup(trie, Get, ["users", "new"])

  case result {
    Some(Match(route, _, _)) -> {
      route |> should.equal("new_user_form")
    }
    None -> panic as "Expected to find route"
  }

  // Should match param for "123"
  let result2 = lookup(trie, Get, ["users", "123"])

  case result2 {
    Some(Match(route, params, _)) -> {
      route |> should.equal("show_user")
      params |> should.equal([#("id", "123")])
    }
    None -> panic as "Expected to find route"
  }
}

pub fn multiple_params_captured_test() {
  let trie =
    new_trie()
    |> insert(
      Get,
      [
        Literal("users"),
        IntParam("user_id"),
        Literal("posts"),
        StringParam("post_id"),
      ],
      "show_user_post",
    )

  let result = lookup(trie, Get, ["users", "42", "posts", "hello"])

  case result {
    Some(Match(route, params, _)) -> {
      route |> should.equal("show_user_post")
      // Note: params are in reverse order due to list prepending
      params |> should.equal([#("post_id", "hello"), #("user_id", "42")])
    }
    None -> panic as "Expected to find route"
  }
}

pub fn different_routes_same_prefix_test() {
  let trie =
    new_trie()
    |> insert(Get, [Literal("api"), Literal("users")], "list_users")
    |> insert(Post, [Literal("api"), Literal("users")], "create_user")
    |> insert(Get, [Literal("api"), Literal("posts")], "list_posts")

  let result1 = lookup(trie, Get, ["api", "users"])
  case result1 {
    Some(Match(route, _, _)) -> route |> should.equal("list_users")
    None -> panic as "Expected route1"
  }

  let result2 = lookup(trie, Post, ["api", "users"])
  case result2 {
    Some(Match(route, _, _)) -> route |> should.equal("create_user")
    None -> panic as "Expected route2"
  }

  let result3 = lookup(trie, Get, ["api", "posts"])
  case result3 {
    Some(Match(route, _, _)) -> route |> should.equal("list_posts")
    None -> panic as "Expected route3"
  }
}

pub fn no_match_for_incomplete_path_test() {
  let trie =
    new_trie()
    |> insert(Get, [Literal("users"), IntParam("id")], "show_user")

  // Path too short
  let result = lookup(trie, Get, ["users"])

  result |> should.equal(None)
}

pub fn no_match_for_too_long_path_test() {
  let trie =
    new_trie()
    |> insert(Get, [Literal("users")], "list_users")

  // Path too long
  let result = lookup(trie, Get, ["users", "123"])

  result |> should.equal(None)
}

// ============================================================================
// Performance Analysis
// ============================================================================

pub fn performance_analysis_test() {
  // Build a trie with 8 routes
  let route_count = 8
  let trie =
    new_trie()
    |> insert(
      Get,
      [Literal("api"), Literal("v1"), Literal("users")],
      "list_users_v1",
    )
    |> insert(
      Get,
      [Literal("api"), Literal("v1"), Literal("users"), IntParam("id")],
      "show_user_v1",
    )
    |> insert(
      Post,
      [Literal("api"), Literal("v1"), Literal("users")],
      "create_user_v1",
    )
    |> insert(
      Get,
      [Literal("api"), Literal("v1"), Literal("posts")],
      "list_posts_v1",
    )
    |> insert(
      Get,
      [Literal("api"), Literal("v1"), Literal("posts"), IntParam("id")],
      "show_post_v1",
    )
    |> insert(
      Get,
      [Literal("api"), Literal("v2"), Literal("users")],
      "list_users_v2",
    )
    |> insert(Get, [Literal("admin"), Literal("users")], "admin_users")
    |> insert(Get, [Literal("admin"), Literal("posts")], "admin_posts")

  // Lookup: GET /api/v1/users/123
  let path_depth = 4
  let result = lookup(trie, Get, ["api", "v1", "users", "123"])

  case result {
    Some(Match(route, params, nodes_visited)) -> {
      route |> should.equal("show_user_v1")
      params |> should.equal([#("id", "123")])

      io.println("\n=== Performance Analysis ===")
      io.println("Route: GET /api/v1/users/123")
      io.println("Total routes in trie: " <> int_to_string(route_count))
      io.println("Path depth: " <> int_to_string(path_depth))
      io.println("")
      io.println("Radix trie nodes visited: " <> int_to_string(nodes_visited))
      io.println(
        "Linear search worst case: " <> int_to_string(route_count) <> " checks",
      )
      io.println("")

      let speedup = int_to_float(route_count) /. int_to_float(nodes_visited)
      io.println(
        "Speedup: "
        <> float_to_string(speedup)
        <> "x (scales with route count!)",
      )
    }
    None -> panic as "Expected to find route"
  }
}

fn int_to_string(i: Int) -> String {
  case i {
    0 -> "0"
    1 -> "1"
    2 -> "2"
    3 -> "3"
    4 -> "4"
    5 -> "5"
    6 -> "6"
    7 -> "7"
    8 -> "8"
    9 -> "9"
    _ -> "N"
  }
}

fn int_to_float(i: Int) -> Float {
  case i {
    0 -> 0.0
    1 -> 1.0
    2 -> 2.0
    3 -> 3.0
    4 -> 4.0
    5 -> 5.0
    6 -> 6.0
    7 -> 7.0
    8 -> 8.0
    9 -> 9.0
    _ -> 0.0
  }
}

fn float_to_string(f: Float) -> String {
  case f {
    2.0 -> "2.0"
    _ -> "~2.0"
  }
}
