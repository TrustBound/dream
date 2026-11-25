//// Radix Trie - Fast route matching data structure
////
//// Guide: [Route requests and add middleware](https://hexdocs.pm/dream/3.0.0/guides/routing.html).
////
//// Provides O(path depth) route lookup instead of O(number of routes) linear search.
//// This is the core data structure used by Dream's router for efficient route matching.
////
//// ## Performance Characteristics
////
//// - **Insert**: O(segments in pattern) - typically 3-5 segments
//// - **Lookup**: O(segments in path) - independent of total number of routes
////   when the first candidate at each segment leads to the route; a lookup
////   that goes back also visits the nodes it abandons
//// - **Memory**: O(total segments across all routes)
////
//// ## How It Works
////
//// The trie organizes routes as a tree where each level represents a path segment.
//// Nodes are prioritized in this order:
//// 1. Literal matches (exact string match)
//// 2. Parameter matches (:id)
//// 3. Single wildcards (*)
//// 4. Multi-wildcards (**)
////
//// A segment with an extension, such as `photo.jpg`, uses a different order:
//// literal, extension pattern (*.jpg), single wildcard, multi-wildcard, and
//// parameter last.
////
//// When a node matches a segment but no route is found below it, the lookup
//// goes back and tries the node of next priority. The first full match in
//// priority order wins, and only the params of that route are returned.
////
//// ## Example
////
//// Routes: `/users/:id`, `/users/new`, `/files/**path`
////
//// Tree structure:
//// ```text illustration
//// root
////   ├─ users
////   │  ├─ new (literal - highest priority)
////   │  └─ :id (param - lower priority)
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
/// - `LiteralExtension`: Matches a specific base name with allowed extensions
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

  /// Extension pattern matching specific file extensions (wildcard)
  /// Example: `["jpg", "png"]` in `/images/*.{jpg,png}`
  ExtensionPattern(extensions: List(String))

  /// Literal with specific extensions (not wildcard)
  /// Example: `products` with `["json", "xml"]` for `/products.{json,xml}`
  /// Matches `products.json` or `products.xml` but not `other.json`
  LiteralExtension(base: String, extensions: List(String))
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
    /// Child nodes for literal+extension patterns (products.{json,xml})
    literal_extension_children: List(#(String, List(String), TrieNode(route))),
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
/// ### Create a trie <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_core_trie.gleam#L6-L11"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn users_trie(user_handler) {
///   let trie =
///     new()
///     |> insert("GET", [Literal("users")], user_handler)
///   trie
/// }
/// ```
pub fn new() -> RadixTrie(route) {
  RadixTrie(root: empty_node())
}

/// Create an empty trie node with no routes or children
fn empty_node() -> TrieNode(route) {
  TrieNode(
    routes: dict.new(),
    literal_children: dict.new(),
    literal_extension_children: [],
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
/// ### Insert routes <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_core_trie.gleam#L13-L19"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn user_trie(handler, create_handler) {
///   let trie =
///     new()
///     |> insert("GET", [Literal("users"), Param("id")], handler)
///     |> insert("POST", [Literal("users")], create_handler)
///   trie
/// }
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
    [LiteralExtension(base, extensions), ..rest] ->
      insert_literal_extension_segment(
        node,
        base,
        extensions,
        method,
        rest,
        route,
      )
    [Param(name), ..rest] ->
      insert_param_segment(node, name, method, rest, route)
    [SingleWildcard(name), ..rest] ->
      insert_wildcard_segment(node, name, method, rest, route)
    [MultiWildcard(name), ..rest] ->
      insert_multi_wildcard_segment(node, name, method, rest, route)
    [ExtensionPattern(extensions), ..rest] ->
      insert_extension_segment(node, extensions, method, rest, route)
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

/// Insert a literal+extension segment and recurse into its child
fn insert_literal_extension_segment(
  node: TrieNode(route),
  base: String,
  extensions: List(String),
  method: String,
  rest: List(Segment),
  route: route,
) -> TrieNode(route) {
  let child = get_or_create_literal_extension_child(node, base, extensions)
  let updated_child = insert_into_node(child, method, rest, route)
  let updated_children =
    update_literal_extension_children(
      node.literal_extension_children,
      base,
      extensions,
      updated_child,
    )
  TrieNode(..node, literal_extension_children: updated_children)
}

/// Get existing literal extension child or create a new empty node
fn get_or_create_literal_extension_child(
  node: TrieNode(route),
  base: String,
  extensions: List(String),
) -> TrieNode(route) {
  case
    find_literal_extension_child(
      node.literal_extension_children,
      base,
      extensions,
    )
  {
    Some(existing) -> existing
    None -> empty_node()
  }
}

/// Find a literal extension child matching the given base and extensions
fn find_literal_extension_child(
  children: List(#(String, List(String), TrieNode(route))),
  base: String,
  extensions: List(String),
) -> Option(TrieNode(route)) {
  case children {
    [] -> None
    [#(child_base, child_extensions, child), ..rest_children] ->
      case child_base == base && child_extensions == extensions {
        True -> Some(child)
        False -> find_literal_extension_child(rest_children, base, extensions)
      }
  }
}

/// Update or add a literal extension child in the children list
fn update_literal_extension_children(
  children: List(#(String, List(String), TrieNode(route))),
  base: String,
  extensions: List(String),
  new_child: TrieNode(route),
) -> List(#(String, List(String), TrieNode(route))) {
  case children {
    [] -> [#(base, extensions, new_child)]
    [#(child_base, child_extensions, child), ..rest_children] ->
      case child_base == base && child_extensions == extensions {
        True -> [#(base, extensions, new_child), ..rest_children]
        False -> [
          #(child_base, child_extensions, child),
          ..update_literal_extension_children(
            rest_children,
            base,
            extensions,
            new_child,
          )
        ]
      }
  }
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
  extensions: List(String),
  method: String,
  rest: List(Segment),
  route: route,
) -> TrieNode(route) {
  let child = get_or_create_extension_child(node, extensions)
  let updated_child = insert_into_node(child, method, rest, route)
  let updated_children =
    update_extension_children(
      node.extension_children,
      extensions,
      updated_child,
    )
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
fn get_or_create_multi_wildcard_child(
  node: TrieNode(route),
) -> TrieNode(route) {
  case node.multi_wildcard_child {
    Some(#(_, existing)) -> existing
    None -> empty_node()
  }
}

/// Get existing extension child or create a new empty node
fn get_or_create_extension_child(
  node: TrieNode(route),
  extensions: List(String),
) -> TrieNode(route) {
  case find_extension_child(node.extension_children, extensions) {
    Some(existing) -> existing
    None -> empty_node()
  }
}

/// Find an extension child matching the given extension list
fn find_extension_child(
  children: List(#(List(String), TrieNode(route))),
  extensions: List(String),
) -> Option(TrieNode(route)) {
  case children {
    [] -> None
    [#(child_extensions, child), ..rest] ->
      case child_extensions == extensions {
        True -> Some(child)
        False -> find_extension_child(rest, extensions)
      }
  }
}

/// Update or add an extension child in the children list
fn update_extension_children(
  children: List(#(List(String), TrieNode(route))),
  extensions: List(String),
  new_child: TrieNode(route),
) -> List(#(List(String), TrieNode(route))) {
  case children {
    [] -> [#(extensions, new_child)]
    [#(child_extensions, child), ..rest] ->
      case child_extensions == extensions {
        True -> [#(extensions, new_child), ..rest]
        False -> [
          #(child_extensions, child),
          ..update_extension_children(rest, extensions, new_child)
        ]
      }
  }
}

// ============================================================================
// Trie Listing
// ============================================================================

/// Every route of the trie, as its method key, its segments and its route
///
/// The router uses this list to copy the routes of one router into another
/// (see `dream/router.scope`). The order of the list is not defined.
///
/// A trie node keeps one name for a parameter or a wildcard segment, so
/// routes that share that node give the same name here, also when their
/// patterns used different names. The router keeps the names of each route
/// in its route handler, so that does not change the names that a matched
/// route gets.
@internal
pub fn routes(trie: RadixTrie(route)) -> List(#(String, List(Segment), route)) {
  node_routes(trie.root, [], [])
}

/// Adds the routes of a node and of all nodes below it to `found`.
/// `reversed_path` holds the segments from the root to the node, last first.
fn node_routes(
  node: TrieNode(route),
  reversed_path: List(Segment),
  found: List(#(String, List(Segment), route)),
) -> List(#(String, List(Segment), route)) {
  found
  |> routes_at_node(dict.to_list(node.routes), list.reverse(reversed_path), _)
  |> literal_child_routes(dict.to_list(node.literal_children), reversed_path, _)
  |> literal_extension_child_routes(
    node.literal_extension_children,
    reversed_path,
    _,
  )
  |> optional_child_routes(
    param_child_entry(node.param_child),
    reversed_path,
    _,
  )
  |> optional_child_routes(
    wildcard_child_entry(node.wildcard_child),
    reversed_path,
    _,
  )
  |> optional_child_routes(
    multi_wildcard_child_entry(node.multi_wildcard_child),
    reversed_path,
    _,
  )
  |> extension_child_routes(node.extension_children, reversed_path, _)
}

fn routes_at_node(
  method_routes: List(#(String, route)),
  path: List(Segment),
  found: List(#(String, List(Segment), route)),
) -> List(#(String, List(Segment), route)) {
  case method_routes {
    [] -> found
    [#(method, route), ..rest] ->
      routes_at_node(rest, path, [#(method, path, route), ..found])
  }
}

fn literal_child_routes(
  children: List(#(String, TrieNode(route))),
  reversed_path: List(Segment),
  found: List(#(String, List(Segment), route)),
) -> List(#(String, List(Segment), route)) {
  case children {
    [] -> found
    [#(name, child), ..rest] ->
      literal_child_routes(
        rest,
        reversed_path,
        node_routes(child, [Literal(name), ..reversed_path], found),
      )
  }
}

fn literal_extension_child_routes(
  children: List(#(String, List(String), TrieNode(route))),
  reversed_path: List(Segment),
  found: List(#(String, List(Segment), route)),
) -> List(#(String, List(Segment), route)) {
  case children {
    [] -> found
    [#(base, extensions, child), ..rest] ->
      literal_extension_child_routes(
        rest,
        reversed_path,
        node_routes(
          child,
          [LiteralExtension(base, extensions), ..reversed_path],
          found,
        ),
      )
  }
}

fn extension_child_routes(
  children: List(#(List(String), TrieNode(route))),
  reversed_path: List(Segment),
  found: List(#(String, List(Segment), route)),
) -> List(#(String, List(Segment), route)) {
  case children {
    [] -> found
    [#(extensions, child), ..rest] ->
      extension_child_routes(
        rest,
        reversed_path,
        node_routes(
          child,
          [ExtensionPattern(extensions), ..reversed_path],
          found,
        ),
      )
  }
}

fn optional_child_routes(
  child: Option(#(Segment, TrieNode(route))),
  reversed_path: List(Segment),
  found: List(#(String, List(Segment), route)),
) -> List(#(String, List(Segment), route)) {
  case child {
    None -> found
    Some(#(segment, node)) ->
      node_routes(node, [segment, ..reversed_path], found)
  }
}

fn param_child_entry(
  child: Option(#(String, TrieNode(route))),
) -> Option(#(Segment, TrieNode(route))) {
  case child {
    None -> None
    Some(#(name, node)) -> Some(#(Param(name), node))
  }
}

fn wildcard_child_entry(
  child: Option(#(Option(String), TrieNode(route))),
) -> Option(#(Segment, TrieNode(route))) {
  case child {
    None -> None
    Some(#(name, node)) -> Some(#(SingleWildcard(name), node))
  }
}

fn multi_wildcard_child_entry(
  child: Option(#(Option(String), TrieNode(route))),
) -> Option(#(Segment, TrieNode(route))) {
  case child {
    None -> None
    Some(#(name, node)) -> Some(#(MultiWildcard(name), node))
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
/// ### Look up a path <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_core_trie.gleam#L21-L32"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// pub fn find_user(trie) {
///   let result = lookup(trie, "GET", ["users", "123"])
///   case result {
///     Some(Match(route, params)) -> {
///       // params = [#("id", "123")]
///       // route is the handler
///       Ok(#(route, params))
///     }
///     // No matching route
///     None -> Error(Nil)
///   }
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
/// 2. Literal+extension pattern (products.{json,xml})
/// 3. Extension pattern (*.jpg) - checked before extension stripping
/// 4. Literal without extension (e.g., "products.json" -> "products")
/// 5. Parameter (:id)
/// 6. Single wildcard (*)
/// 7. Multi-wildcard (**)
///
/// When a candidate matches the segment but its subtree finds no route,
/// the lookup goes back and tries the next candidate. The first full match
/// in priority order wins. Params are passed down as an immutable list, so
/// an abandoned candidate leaves no params behind.
fn lookup_segment(
  node: TrieNode(route),
  method: String,
  segment: String,
  rest: List(String),
  params: List(#(String, String)),
) -> Option(Match(route)) {
  case try_literal_match(node, method, segment, rest, params) {
    Some(match) -> Some(match)
    None -> lookup_segment_after_literal(node, method, segment, rest, params)
  }
}

/// Continue the segment lookup with literal+extension patterns
fn lookup_segment_after_literal(
  node: TrieNode(route),
  method: String,
  segment: String,
  rest: List(String),
  params: List(#(String, String)),
) -> Option(Match(route)) {
  let literal_extension_result =
    try_literal_extension_match(
      node.literal_extension_children,
      segment,
      method,
      rest,
      params,
    )
  case literal_extension_result {
    Some(match) -> Some(match)
    None ->
      lookup_segment_after_literal_extension(
        node,
        method,
        segment,
        rest,
        params,
      )
  }
}

/// Continue the segment lookup with wildcard extension patterns (*.jpg)
fn lookup_segment_after_literal_extension(
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
    None -> try_literal_without_extension(node, method, segment, rest, params)
  }
}

/// Try to match segment as a literal child
fn try_literal_match(
  node: TrieNode(route),
  method: String,
  name: String,
  rest: List(String),
  params: List(#(String, String)),
) -> Option(Match(route)) {
  case dict.get(node.literal_children, name) {
    Ok(child) -> lookup_in_node(child, method, rest, params)
    Error(_) -> None
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
  case strip_extension_from_segment(segment) {
    Some(base_name) ->
      lookup_segment_with_extension(
        node,
        method,
        base_name,
        segment,
        rest,
        params,
      )
    // No extension to strip, proceed with normal matching
    None -> try_param_match(node, method, segment, rest, params)
  }
}

/// Match a segment with an extension after the extension patterns failed
///
/// Tries the base name as a literal first, then the wildcards with the full
/// segment, then the parameter last.
fn lookup_segment_with_extension(
  node: TrieNode(route),
  method: String,
  base_name: String,
  segment: String,
  rest: List(String),
  params: List(#(String, String)),
) -> Option(Match(route)) {
  case try_literal_match(node, method, base_name, rest, params) {
    Some(match) -> Some(match)
    None -> try_wildcard_then_param_match(node, method, segment, rest, params)
  }
}

/// Try the wildcards with the full segment, then the parameter
///
/// The parameter stores the original segment (e.g., "1.json" -> id="1.json")
/// so format detection works in controllers.
fn try_wildcard_then_param_match(
  node: TrieNode(route),
  method: String,
  segment: String,
  rest: List(String),
  params: List(#(String, String)),
) -> Option(Match(route)) {
  case try_wildcard_match(node, method, segment, rest, params) {
    Some(match) -> Some(match)
    None -> try_param_only(node, method, segment, rest, params)
  }
}

/// Strip extension from a segment if it has one
///
/// Returns the base name without extension, or None if no extension found.
/// Example: "products.json" -> Some("products"), "products" -> None
fn strip_extension_from_segment(segment: String) -> option.Option(String) {
  case string.split(segment, ".") {
    [base_name, _extension] -> option.Some(base_name)
    _ -> option.None
  }
}

/// Try to match segment as a parameter, then as the wildcards
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
  case try_param_only(node, method, segment, rest, params) {
    Some(match) -> Some(match)
    None -> try_wildcard_match(node, method, segment, rest, params)
  }
}

/// Try to match segment as the parameter child only
///
/// The parameter captures the full segment (including extension if present).
fn try_param_only(
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
    None -> None
  }
}

/// Try to match segment as a single wildcard, then as a multi-wildcard
fn try_wildcard_match(
  node: TrieNode(route),
  method: String,
  segment: String,
  rest: List(String),
  params: List(#(String, String)),
) -> Option(Match(route)) {
  case try_single_wildcard_only(node, method, segment, rest, params) {
    Some(match) -> Some(match)
    None -> try_multi_wildcard_match(node, method, segment, rest, params)
  }
}

/// Try to match segment as the single wildcard child only
fn try_single_wildcard_only(
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
    None -> None
  }
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

/// Try to match segment against literal+extension patterns (products.{json,xml})
///
/// When a matching child finds no route, the next child is tried.
fn try_literal_extension_match(
  children: List(#(String, List(String), TrieNode(route))),
  segment: String,
  method: String,
  rest: List(String),
  params: List(#(String, String)),
) -> Option(Match(route)) {
  case children {
    [] -> None
    [#(base, extensions, child), ..remaining] ->
      case matches_literal_extension(segment, base, extensions) {
        True ->
          lookup_literal_extension_child(
            child,
            remaining,
            segment,
            method,
            rest,
            params,
          )
        False ->
          try_literal_extension_match(remaining, segment, method, rest, params)
      }
  }
}

/// Look up a matching literal+extension child, or try the remaining children
fn lookup_literal_extension_child(
  child: TrieNode(route),
  remaining: List(#(String, List(String), TrieNode(route))),
  segment: String,
  method: String,
  rest: List(String),
  params: List(#(String, String)),
) -> Option(Match(route)) {
  case lookup_in_node(child, method, rest, params) {
    Some(match) -> Some(match)
    None ->
      try_literal_extension_match(remaining, segment, method, rest, params)
  }
}

/// Check if a segment matches a literal+extension pattern
///
/// Example: "products.json" matches base="products" with extensions=["json", "xml"]
fn matches_literal_extension(
  segment: String,
  base: String,
  extensions: List(String),
) -> Bool {
  let prefix = base <> "."
  case string.starts_with(segment, prefix) {
    True -> {
      let segment_extension = string.drop_start(segment, string.length(prefix))
      list.contains(extensions, segment_extension)
    }
    False -> False
  }
}

/// Try to match segment against extension patterns
///
/// When a matching child finds no route, the next child is tried.
fn try_extension_match(
  extension_children: List(#(List(String), TrieNode(route))),
  segment: String,
  method: String,
  rest: List(String),
  params: List(#(String, String)),
) -> Option(Match(route)) {
  case extension_children {
    [] -> None
    [#(extensions, child), ..remaining] ->
      case matches_any_extension(segment, extensions) {
        True ->
          lookup_extension_child(
            child,
            remaining,
            segment,
            method,
            rest,
            params,
          )
        False -> try_extension_match(remaining, segment, method, rest, params)
      }
  }
}

/// Look up a matching extension pattern child, or try the remaining children
fn lookup_extension_child(
  child: TrieNode(route),
  remaining: List(#(List(String), TrieNode(route))),
  segment: String,
  method: String,
  rest: List(String),
  params: List(#(String, String)),
) -> Option(Match(route)) {
  case lookup_in_node(child, method, rest, params) {
    Some(match) -> Some(match)
    None -> try_extension_match(remaining, segment, method, rest, params)
  }
}

/// Check if a filename matches any of the given extensions
fn matches_any_extension(filename: String, extensions: List(String)) -> Bool {
  list.any(extensions, check_extension_match(filename, _))
}

/// Check if a filename ends with a specific extension
///
/// This is a named function to avoid anonymous functions in production code.
fn check_extension_match(filename: String, extension: String) -> Bool {
  string.ends_with(filename, "." <> extension)
}
