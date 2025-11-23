// Radix Trie - Standalone implementation for fast route matching
//
// Provides O(path depth) route lookup instead of O(number of routes) linear search

import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

// ============================================================================
// Types
// ============================================================================

/// Segment types for route patterns
pub type Segment {
  Literal(String)
  Param(name: String)
  SingleWildcard(name: Option(String))
  MultiWildcard(name: Option(String))
  ExtensionPattern(extensions: List(String))
}

/// A node in the radix trie
pub type TrieNode(route) {
  TrieNode(
    routes: Dict(String, route),
    literal_children: Dict(String, TrieNode(route)),
    param_child: Option(#(String, TrieNode(route))),
    wildcard_child: Option(#(Option(String), TrieNode(route))),
    multi_wildcard_child: Option(#(Option(String), TrieNode(route))),
    extension_children: List(#(List(String), TrieNode(route))),
  )
}

/// Radix trie for fast route lookup
pub type RadixTrie(route) {
  RadixTrie(root: TrieNode(route))
}

/// Result of a route lookup
pub type Match(route) {
  Match(route: route, params: List(#(String, String)))
}

// ============================================================================
// Trie Construction
// ============================================================================

pub fn new() -> RadixTrie(route) {
  RadixTrie(root: empty_node())
}

fn empty_node() -> TrieNode(route) {
  TrieNode(
    routes: dict.new(),
    literal_children: dict.new(),
    param_child: None,
    wildcard_child: None,
    multi_wildcard_child: None,
    extension_children: [],
  )
}

pub fn insert(
  trie: RadixTrie(route),
  method: String,
  segments: List(Segment),
  route: route,
) -> RadixTrie(route) {
  let updated_root = insert_into_node(trie.root, method, segments, route)
  RadixTrie(root: updated_root)
}

fn insert_into_node(
  node: TrieNode(route),
  method: String,
  segments: List(Segment),
  route: route,
) -> TrieNode(route) {
  case segments {
    [] -> insert_route_at_node(node, method, route)
    [Literal(name), ..rest] ->
      insert_literal_segment(node, name, method, rest, route)
    [Param(name), ..rest] ->
      insert_param_segment(node, name, method, rest, route)
    [SingleWildcard(name), ..rest] ->
      insert_wildcard_segment(node, name, method, rest, route)
    [MultiWildcard(name), ..rest] ->
      insert_multi_wildcard_segment(node, name, method, rest, route)
    [ExtensionPattern(exts), ..rest] ->
      insert_extension_segment(node, exts, method, rest, route)
  }
}

fn insert_route_at_node(
  node: TrieNode(route),
  method: String,
  route: route,
) -> TrieNode(route) {
  let updated_routes = dict.insert(node.routes, method, route)
  TrieNode(..node, routes: updated_routes)
}

fn insert_literal_segment(
  node: TrieNode(route),
  name: String,
  method: String,
  rest: List(Segment),
  route: route,
) -> TrieNode(route) {
  let child = get_or_create_literal_child(node, name)
  let updated_child = insert_into_node(child, method, rest, route)
  let updated_children = dict.insert(node.literal_children, name, updated_child)
  TrieNode(..node, literal_children: updated_children)
}

fn insert_param_segment(
  node: TrieNode(route),
  name: String,
  method: String,
  rest: List(Segment),
  route: route,
) -> TrieNode(route) {
  let child = get_or_create_param_child(node)
  let updated_child = insert_into_node(child, method, rest, route)
  TrieNode(..node, param_child: Some(#(name, updated_child)))
}

fn insert_wildcard_segment(
  node: TrieNode(route),
  name: Option(String),
  method: String,
  rest: List(Segment),
  route: route,
) -> TrieNode(route) {
  let child = get_or_create_wildcard_child(node)
  let updated_child = insert_into_node(child, method, rest, route)
  TrieNode(..node, wildcard_child: Some(#(name, updated_child)))
}

fn insert_multi_wildcard_segment(
  node: TrieNode(route),
  name: Option(String),
  method: String,
  rest: List(Segment),
  route: route,
) -> TrieNode(route) {
  let child = get_or_create_multi_wildcard_child(node)
  let updated_child = insert_into_node(child, method, rest, route)
  TrieNode(..node, multi_wildcard_child: Some(#(name, updated_child)))
}

fn insert_extension_segment(
  node: TrieNode(route),
  exts: List(String),
  method: String,
  rest: List(Segment),
  route: route,
) -> TrieNode(route) {
  let child = get_or_create_extension_child(node, exts)
  let updated_child = insert_into_node(child, method, rest, route)
  let updated_children =
    update_extension_children(node.extension_children, exts, updated_child)
  TrieNode(..node, extension_children: updated_children)
}

fn get_or_create_literal_child(
  node: TrieNode(route),
  name: String,
) -> TrieNode(route) {
  case dict.get(node.literal_children, name) {
    Ok(existing) -> existing
    Error(_) -> empty_node()
  }
}

fn get_or_create_param_child(node: TrieNode(route)) -> TrieNode(route) {
  case node.param_child {
    Some(#(_, existing)) -> existing
    None -> empty_node()
  }
}

fn get_or_create_wildcard_child(node: TrieNode(route)) -> TrieNode(route) {
  case node.wildcard_child {
    Some(#(_, existing)) -> existing
    None -> empty_node()
  }
}

fn get_or_create_multi_wildcard_child(node: TrieNode(route)) -> TrieNode(route) {
  case node.multi_wildcard_child {
    Some(#(_, existing)) -> existing
    None -> empty_node()
  }
}

fn get_or_create_extension_child(
  node: TrieNode(route),
  exts: List(String),
) -> TrieNode(route) {
  case find_extension_child(node.extension_children, exts) {
    Some(existing) -> existing
    None -> empty_node()
  }
}

fn find_extension_child(
  children: List(#(List(String), TrieNode(route))),
  exts: List(String),
) -> Option(TrieNode(route)) {
  case children {
    [] -> None
    [#(child_exts, child), ..rest] ->
      case child_exts == exts {
        True -> Some(child)
        False -> find_extension_child(rest, exts)
      }
  }
}

fn update_extension_children(
  children: List(#(List(String), TrieNode(route))),
  exts: List(String),
  new_child: TrieNode(route),
) -> List(#(List(String), TrieNode(route))) {
  case children {
    [] -> [#(exts, new_child)]
    [#(child_exts, child), ..rest] ->
      case child_exts == exts {
        True -> [#(exts, new_child), ..rest]
        False -> [
          #(child_exts, child),
          ..update_extension_children(rest, exts, new_child)
        ]
      }
  }
}

// ============================================================================
// Trie Lookup
// ============================================================================

pub fn lookup(
  trie: RadixTrie(route),
  method: String,
  path_segments: List(String),
) -> Option(Match(route)) {
  lookup_in_node(trie.root, method, path_segments, [])
}

fn lookup_in_node(
  node: TrieNode(route),
  method: String,
  path_segments: List(String),
  params: List(#(String, String)),
) -> Option(Match(route)) {
  case path_segments {
    [] -> lookup_route_at_node(node, method, params)
    [segment, ..rest] -> lookup_segment(node, method, segment, rest, params)
  }
}

fn lookup_route_at_node(
  node: TrieNode(route),
  method: String,
  params: List(#(String, String)),
) -> Option(Match(route)) {
  case dict.get(node.routes, method) {
    Ok(route) -> Some(Match(route, params))
    Error(_) -> None
  }
}

fn lookup_segment(
  node: TrieNode(route),
  method: String,
  segment: String,
  rest: List(String),
  params: List(#(String, String)),
) -> Option(Match(route)) {
  // Try literal match first (highest precedence)
  case dict.get(node.literal_children, segment) {
    Ok(child) -> lookup_in_node(child, method, rest, params)
    Error(_) -> try_param_match(node, method, segment, rest, params)
  }
}

fn try_param_match(
  node: TrieNode(route),
  method: String,
  segment: String,
  rest: List(String),
  params: List(#(String, String)),
) -> Option(Match(route)) {
  case node.param_child {
    Some(#(param_name, child)) -> {
      let updated_params = [#(param_name, segment), ..params]
      lookup_in_node(child, method, rest, updated_params)
    }
    None -> try_wildcard_match(node, method, segment, rest, params)
  }
}

fn try_wildcard_match(
  node: TrieNode(route),
  method: String,
  segment: String,
  rest: List(String),
  params: List(#(String, String)),
) -> Option(Match(route)) {
  case node.wildcard_child {
    Some(#(wildcard_name, child)) -> {
      let param_name = option.unwrap(wildcard_name, "wildcard")
      let updated_params = [#(param_name, segment), ..params]
      lookup_in_node(child, method, rest, updated_params)
    }
    None -> try_extension_or_multi_wildcard(node, method, segment, rest, params)
  }
}

fn try_extension_or_multi_wildcard(
  node: TrieNode(route),
  method: String,
  segment: String,
  rest: List(String),
  params: List(#(String, String)),
) -> Option(Match(route)) {
  let extension_result =
    try_extension_match(node.extension_children, segment, method, rest, params)

  case extension_result {
    Some(match) -> Some(match)
    None -> try_multi_wildcard_match(node, method, segment, rest, params)
  }
}

fn try_multi_wildcard_match(
  node: TrieNode(route),
  method: String,
  segment: String,
  rest: List(String),
  params: List(#(String, String)),
) -> Option(Match(route)) {
  case node.multi_wildcard_child {
    Some(#(wildcard_name, child)) -> {
      let param_name = option.unwrap(wildcard_name, "path")
      let all_segments = [segment, ..rest]
      let captured = string.join(all_segments, "/")
      let updated_params = [#(param_name, captured), ..params]
      lookup_in_node(child, method, [], updated_params)
    }
    None -> None
  }
}

fn try_extension_match(
  extension_children: List(#(List(String), TrieNode(route))),
  segment: String,
  method: String,
  rest: List(String),
  params: List(#(String, String)),
) -> Option(Match(route)) {
  case extension_children {
    [] -> None
    [#(exts, child), ..remaining] ->
      case matches_any_extension(segment, exts) {
        True -> lookup_in_node(child, method, rest, params)
        False -> try_extension_match(remaining, segment, method, rest, params)
      }
  }
}

fn matches_any_extension(filename: String, extensions: List(String)) -> Bool {
  list.any(extensions, fn(ext) { string.ends_with(filename, "." <> ext) })
}
