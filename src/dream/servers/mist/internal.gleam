//// Internal bridge between Mist and Dream for WebSockets, SSE, and streaming
////
//// This module uses the Erlang process dictionary to stash per-request data
//// (the current Mist request and an optional upgrade response). It is used by
//// the Mist handler, WebSocket, and SSE modules to coordinate HTTP → WebSocket
//// and HTTP → SSE upgrades and should not be used directly by application code.

import gleam/dynamic.{type Dynamic}
import gleam/erlang/atom.{type Atom}

/// The process dictionary key that holds the current Mist request.
///
/// The handler stores the request under this key. `upgrade_to_sse` and
/// `upgrade_websocket` read it back.
pub const request_key = "dream_mist_request"

/// The process dictionary key that holds the upgrade response.
///
/// The handler sets it to `None` for each request. `upgrade_websocket` stores
/// the Mist WebSocket response under it, and the handler returns that
/// response in place of the normal one.
pub const response_key = "dream_mist_response"

/// The process dictionary key that holds a deferred upgrade.
///
/// The handler sets it to `None` for each request. `upgrade_to_sse` stores a
/// function that does the SSE upgrade under it. After the controller returns,
/// the handler calls that function when the response status is 200.
pub const upgrade_key = "dream_mist_upgrade"

/// Stores a value under a key in the process dictionary of the calling
/// process.
///
/// Returns the value that the key held before, or the atom `undefined`.
///
/// ## Example
///
/// ### Store and read a value <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_server_internal.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/servers/mist/internal
/// import gleam/erlang/atom
///
/// pub fn stash_and_read() -> String {
///   let key = atom.create("doc_example_key")
///   // put stores a value in the process dictionary of this process
///   let _previous = internal.put(key, internal.to_dynamic("hello"))
///   // get reads it back as a Dynamic, and unsafe_coerce gives back its type:
///   // "hello"
///   internal.unsafe_coerce(internal.get(key))
/// }
/// ```
@external(erlang, "erlang", "put")
pub fn put(key: Atom, value: Dynamic) -> Dynamic

/// Reads the value under a key from the process dictionary of the calling
/// process.
///
/// Returns the atom `undefined` when the key holds no value.
///
/// ## Example
///
/// ### Store and read a value <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_server_internal.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/servers/mist/internal
/// import gleam/erlang/atom
///
/// pub fn stash_and_read() -> String {
///   let key = atom.create("doc_example_key")
///   // put stores a value in the process dictionary of this process
///   let _previous = internal.put(key, internal.to_dynamic("hello"))
///   // get reads it back as a Dynamic, and unsafe_coerce gives back its type:
///   // "hello"
///   internal.unsafe_coerce(internal.get(key))
/// }
/// ```
@external(erlang, "erlang", "get")
pub fn get(key: Atom) -> Dynamic

/// Converts any value to a `Dynamic`. The value does not change.
///
/// ## Example
///
/// ### Store and read a value <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_server_internal.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/servers/mist/internal
/// import gleam/erlang/atom
///
/// pub fn stash_and_read() -> String {
///   let key = atom.create("doc_example_key")
///   // put stores a value in the process dictionary of this process
///   let _previous = internal.put(key, internal.to_dynamic("hello"))
///   // get reads it back as a Dynamic, and unsafe_coerce gives back its type:
///   // "hello"
///   internal.unsafe_coerce(internal.get(key))
/// }
/// ```
@external(erlang, "gleam_stdlib", "identity")
pub fn to_dynamic(value: a) -> Dynamic

/// Gives a value any type. The value does not change and is not checked.
///
/// Use it only for a value that you know has the new type, such as a value
/// that you stored with `put`.
///
/// ## Example
///
/// ### Store and read a value <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_server_internal.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
///
/// ```gleam
/// import dream/servers/mist/internal
/// import gleam/erlang/atom
///
/// pub fn stash_and_read() -> String {
///   let key = atom.create("doc_example_key")
///   // put stores a value in the process dictionary of this process
///   let _previous = internal.put(key, internal.to_dynamic("hello"))
///   // get reads it back as a Dynamic, and unsafe_coerce gives back its type:
///   // "hello"
///   internal.unsafe_coerce(internal.get(key))
/// }
/// ```
@external(erlang, "gleam_stdlib", "identity")
pub fn unsafe_coerce(value: a) -> b
