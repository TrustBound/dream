//// Radix Trie - Fast route matching data structure
////
//// Provides O(path depth) route lookup instead of O(number of routes) linear search.
//// This is the core data structure used by Dream's router for efficient route matching.
////
//// ## Performance Characteristics
////
//// - **Insert**: O(segments in pattern) - typically 3-5 segments
//// - **Lookup**: O(segments in path) - independent of total number of routes
//// - **Memory**: O(total segments across all routes)
////
//// ## How It Works
////
//// The trie organizes routes as a tree where each level represents a path segment.
//// Nodes are prioritized in this order:
//// 1. Literal matches (exact string match)
//// 2. Parameter matches (:id)
//// 3. Single wildcards (*)
//// 4. Extension patterns (*.jpg)
//// 5. Multi-wildcards (**)
////
//// This ensures the most specific route always wins when multiple routes could match.
////
//// ## Example
////
//// Routes: `/users/:id`, `/users/new`, `/files/**path`
////
//// Tree structure:
//// ```
//// root
////   └─ users
////      ├─ new (literal - highest priority)
////      └─ :id (param - lower priority)
////   └─ files
////      └─ **path (multi-wildcard - lowest priority)
//// ```
////
//// Path `/users/new` matches the literal route, not `:id`.

import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

// ============================================================================
// Types
// ============================================================================

/// Segment types for route patterns
///
/// Each segment type has different matching behavior and priority:
/// - `Literal`: Exact string match, highest priority
/// - `Param`: Named parameter, captures one segment
/// - `SingleWildcard`: Matches one segment, optionally named
/// - `MultiWildcard`: Matches zero or more segments, optionally named
/// - `ExtensionPattern`: Matches filenames with specific extensions
pub type Segment {
  /// Literal segment requiring exact match
  /// Example: `"users"` in `/users/:id`
  Literal(String)

  /// Named parameter capturing one segment
  /// Example: `"id"` in `/users/:id`
  Param(name: String)

  /// Single wildcard matching exactly one segment
  /// Example: `*` or `*file` in `/images/*file`
  SingleWildcard(name: Option(String))

  /// Multi-segment wildcard matching zero or more segments
  /// Example: `**` or `**path` in `/files/**path`
  MultiWildcard(name: Option(String))

  /// Extension pattern matching specific file extensions
  /// Example: `["jpg", "png"]` in `/images/*.{jpg,png}`
  ExtensionPattern(extensions: List(String))
}

/// A node in the radix trie
///
/// Each node can store routes for different HTTP methods and has children
/// for different segment types. Children are organized by priority to ensure
/// correct matching order.
pub opaque type TrieNode(route) {
  TrieNode(
    /// Routes stored at this node, keyed by HTTP method (GET, POST, etc.)
    routes: Dict(String, route),
    /// Child nodes for literal segments (exact matches)
    literal_children: Dict(String, TrieNode(route)),
    /// Child node for parameter segment (:id)
    param_child: Option(#(String, TrieNode(route))),
    /// Child node for single wildcard (*)
    wildcard_child: Option(#(Option(String), TrieNode(route))),
    /// Child node for multi-segment wildcard (**)
    multi_wildcard_child: Option(#(Option(String), TrieNode(route))),
    /// Child nodes for extension patterns (*.jpg)
    extension_children: List(#(List(String), TrieNode(route))),
  )
}

/// Radix trie for fast route lookup
///
/// The trie is the main data structure holding all routes. Routes are
/// organized by path segments for efficient O(path depth) lookup.
pub opaque type RadixTrie(route) {
  RadixTrie(root: TrieNode(route))
}

/// Result of a successful route lookup
///
/// Contains the matched route and any extracted path parameters.
pub type Match(route) {
  Match(
    /// The route that matched the request
    route: route,
    /// Extracted parameters from the path as (name, value) tuples
    params: List(#(String, String)),
  )
}

// ============================================================================
// Trie Construction
// ============================================================================

/// Create a new empty radix trie
///
/// Returns a trie with no routes. Use `insert()` to add routes.
///
/// ## Example
///
/// ```gleam
/// let trie = new()
/// |> insert("GET", [Literal("users")], user_handler)
/// ```
pub fn new() -> RadixTrie(route) {
  RadixTrie(root: empty_node())
}

/// Create an empty trie node with no routes or children
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

/// Insert a route into the trie
///
/// Adds a route at the path specified by the segments. If a route already
/// exists for the same method and path, it is replaced.
///
/// ## Parameters
///
/// - `trie`: The trie to insert into
/// - `method`: HTTP method as string (e.g., "GET", "POST")
/// - `segments`: Path segments from pattern parser
/// - `route`: The route handler to store
///
/// ## Example
///
/// ```gleam
/// let trie = new()
/// |> insert("GET", [Literal("users"), Param("id")], handler)
/// |> insert("POST", [Literal("users")], create_handler)
/// ```
pub fn insert(
  trie: RadixTrie(route),
  method: String,
  segments: List(Segment),
  route: route,
) -> RadixTrie(route) {
  let updated_root = insert_into_node(trie.root, method, segments, route)
  RadixTrie(root: updated_root)
}

/// Insert a route into a specific node, recursing through segments
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

/// Store a route at the current node for a specific HTTP method
fn insert_route_at_node(
  node: TrieNode(route),
  method: String,
  route: route,
) -> TrieNode(route) {
  let updated_routes = dict.insert(node.routes, method, route)
  TrieNode(..node, routes: updated_routes)
}

/// Insert a literal segment and recurse into its child
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

/// Insert a parameter segment and recurse into its child
fn insert_param_segment(
  node: TrieNode(route),
  name: String,
  method: String,
  rest: List(Segment),
  route: route,
) -> TrieNode(route) {
  // If a param_child already exists, preserve its name (first inserted route wins)
  // This ensures all routes sharing the same param position use the same param name
  let param_name = case node.param_child {
    Some(#(existing_name, _)) -> existing_name
    None -> name
  }
  let child = get_or_create_param_child(node)
  let updated_child = insert_into_node(child, method, rest, route)
  TrieNode(..node, param_child: Some(#(param_name, updated_child)))
}

/// Insert a single wildcard segment and recurse into its child
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

/// Insert a multi-segment wildcard and recurse into its child
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

/// Insert an extension pattern segment and recurse into its child
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

/// Get existing literal child or create a new empty node
fn get_or_create_literal_child(
  node: TrieNode(route),
  name: String,
) -> TrieNode(route) {
  case dict.get(node.literal_children, name) {
    Ok(existing) -> existing
    Error(_) -> empty_node()
  }
}

/// Get existing parameter child or create a new empty node
fn get_or_create_param_child(node: TrieNode(route)) -> TrieNode(route) {
  case node.param_child {
    Some(#(_, existing)) -> existing
    None -> empty_node()
  }
}

/// Get existing wildcard child or create a new empty node
fn get_or_create_wildcard_child(node: TrieNode(route)) -> TrieNode(route) {
  case node.wildcard_child {
    Some(#(_, existing)) -> existing
    None -> empty_node()
  }
}

/// Get existing multi-wildcard child or create a new empty node
fn get_or_create_multi_wildcard_child(node: TrieNode(route)) -> TrieNode(route) {
  case node.multi_wildcard_child {
    Some(#(_, existing)) -> existing
    None -> empty_node()
  }
}

/// Get existing extension child or create a new empty node
fn get_or_create_extension_child(
  node: TrieNode(route),
  exts: List(String),
) -> TrieNode(route) {
  case find_extension_child(node.extension_children, exts) {
    Some(existing) -> existing
    None -> empty_node()
  }
}

/// Find an extension child matching the given extension list
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

/// Update or add an extension child in the children list
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

/// Look up a route in the trie
///
/// Searches for a route matching the given HTTP method and path segments.
/// Returns the matched route and extracted parameters, or None if no match.
///
/// Lookup is O(path depth) - independent of the total number of routes in the trie.
///
/// ## Parameters
///
/// - `trie`: The trie to search
/// - `method`: HTTP method as string (e.g., "GET", "POST")
/// - `path_segments`: Path split into segments (e.g., ["users", "123"])
///
/// ## Returns
///
/// - `Some(Match)`: Contains the matched route and extracted parameters
/// - `None`: No route matched the method and path
///
/// ## Example
///
/// ```gleam
/// let result = lookup(trie, "GET", ["users", "123"])
/// case result {
///   Some(Match(route, params)) -> {
///     // params = [#("id", "123")]
///     // route is the handler
///   }
///   None -> // No matching route
/// }
/// ```
pub fn lookup(
  trie: RadixTrie(route),
  method: String,
  path_segments: List(String),
) -> Option(Match(route)) {
  lookup_in_node(trie.root, method, path_segments, [])
}

/// Look up a route starting from a specific node
fn lookup_in_node(
  node: TrieNode(route),
  method: String,
  path_segments: List(String),
  params: List(#(String, String)),
) -> Option(Match(route)) {
  case path_segments {
    [] -> lookup_empty_path(node, method, params)
    [segment, ..rest] -> lookup_segment(node, method, segment, rest, params)
  }
}

/// Look up route when path segments are exhausted
fn lookup_empty_path(
  node: TrieNode(route),
  method: String,
  params: List(#(String, String)),
) -> Option(Match(route)) {
  let route_result = lookup_route_at_node(node, method, params)
  case route_result {
    Some(match) -> Some(match)
    None -> try_multi_wildcard_empty_path(node, method, params)
  }
}

/// Try to match empty path with multi-wildcard (for routes like /public/**)
fn try_multi_wildcard_empty_path(
  node: TrieNode(route),
  method: String,
  params: List(#(String, String)),
) -> Option(Match(route)) {
  case node.multi_wildcard_child {
    Some(#(wildcard_name, child)) -> {
      let param_name = option.unwrap(wildcard_name, "path")
      let updated_params = [#(param_name, ""), ..params]
      lookup_route_at_node(child, method, updated_params)
    }
    None -> None
  }
}

/// Try to find a route at the current node for the given method
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

/// Match a single path segment against the node's children
///
/// Tries matches in priority order:
/// 1. Literal (exact match)
/// 2. Extension pattern (*.jpg) - checked before extension stripping
/// 3. Literal without extension (e.g., "products.json" -> "products")
/// 4. Parameter (:id)
/// 5. Single wildcard (*)
/// 6. Multi-wildcard (**)
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
    Error(_) -> {
      // Try extension patterns before extension stripping
      // This ensures explicit extension routes take precedence
      let extension_result =
        try_extension_match(
          node.extension_children,
          segment,
          method,
          rest,
          params,
        )
      case extension_result {
        Some(match) -> Some(match)
        None ->
          try_literal_without_extension(node, method, segment, rest, params)
      }
    }
  }
}

/// Try matching segment without its extension (e.g., "products.json" -> "products")
///
/// This allows routes like `/products` to match `/products.json`, enabling
/// format detection in controllers without requiring extension pattern routes.
/// Also handles parameter segments with extensions (e.g., "1.json" -> "1").
///
/// Note: Extension stripping only applies to literal and parameter matches.
/// Wildcards always capture the full segment including extensions.
fn try_literal_without_extension(
  node: TrieNode(route),
  method: String,
  segment: String,
  rest: List(String),
  params: List(#(String, String)),
) -> Option(Match(route)) {
  let segment_without_ext = strip_extension_from_segment(segment)
  case segment_without_ext {
    option.Some(base_name) -> {
      // Try matching the base name as a literal first
      case dict.get(node.literal_children, base_name) {
        Ok(child) -> lookup_in_node(child, method, rest, params)
        Error(_) -> {
          // Try wildcard match with original segment first (wildcards capture full segments)
          // Then try param match with stripped segment for matching, but preserve original
          // segment in params so format detection works (e.g., "1.json" -> id="1.json")
          case try_wildcard_match(node, method, segment, rest, params) {
            Some(match) -> Some(match)
            None ->
              try_param_match_with_original(
                node,
                method,
                base_name,
                segment,
                rest,
                params,
              )
          }
        }
      }
    }
    option.None -> {
      // No extension to strip, proceed with normal matching
      try_param_match(node, method, segment, rest, params)
    }
  }
}

/// Strip extension from a segment if it has one
///
/// Returns the base name without extension, or None if no extension found.
/// Example: "products.json" -> Some("products"), "products" -> None
fn strip_extension_from_segment(segment: String) -> option.Option(String) {
  case string.split(segment, ".") {
    [base_name, _ext] -> option.Some(base_name)
    _ -> option.None
  }
}

/// Try to match segment as a parameter
///
/// Note: Parameters capture the full segment including extensions.
/// Extension stripping only applies to literal matches.
fn try_param_match(
  node: TrieNode(route),
  method: String,
  segment: String,
  rest: List(String),
  params: List(#(String, String)),
) -> Option(Match(route)) {
  case node.param_child {
    Some(#(param_name, child)) -> {
      // Capture full segment (including extension if present)
      let updated_params = [#(param_name, segment), ..params]
      lookup_in_node(child, method, rest, updated_params)
    }
    None -> try_wildcard_match(node, method, segment, rest, params)
  }
}

/// Try to match segment as a parameter, using stripped segment for matching
/// but preserving original segment in params for format detection
///
/// This is used when extension stripping is applied - we match using the
/// base name (e.g., "1" from "1.json") but store the original value
/// (e.g., "1.json") in params so controllers can detect the format.
///
/// Note: The stripped_segment parameter is not used directly, but the fact
/// that we're calling this function indicates we've already verified the
/// stripped segment doesn't match as a literal, so we proceed with param matching.
fn try_param_match_with_original(
  node: TrieNode(route),
  method: String,
  _stripped_segment: String,
  original_segment: String,
  rest: List(String),
  params: List(#(String, String)),
) -> Option(Match(route)) {
  case node.param_child {
    Some(#(param_name, child)) -> {
      // Store original segment in params (for format detection)
      // This allows /products/:id to match /products/1.json with id="1.json"
      // so parse_path_param can extract value="1" and format=Some("json")
      let updated_params = [#(param_name, original_segment), ..params]
      lookup_in_node(child, method, rest, updated_params)
    }
    None -> None
  }
}

/// Try to match segment as a single wildcard
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
    None -> try_multi_wildcard_only(node, method, segment, rest, params)
  }
}

/// Try multi-wildcard match (extension patterns already checked earlier)
fn try_multi_wildcard_only(
  node: TrieNode(route),
  method: String,
  segment: String,
  rest: List(String),
  params: List(#(String, String)),
) -> Option(Match(route)) {
  try_multi_wildcard_match(node, method, segment, rest, params)
}

/// Try to match segment as a multi-segment wildcard (captures remaining path)
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

/// Try to match segment against extension patterns
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

/// Check if a filename matches any of the given extensions
fn matches_any_extension(filename: String, extensions: List(String)) -> Bool {
  list.any(extensions, check_extension_match(filename, _))
}

/// Check if a filename ends with a specific extension
///
/// This is a named function to avoid anonymous functions in production code.
fn check_extension_match(filename: String, ext: String) -> Bool {
  string.ends_with(filename, "." <> ext)
}
