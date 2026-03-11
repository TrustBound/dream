//// Internal bridge between Mist and Dream for WebSockets, SSE, and streaming
////
//// This module uses the Erlang process dictionary to stash per-request data
//// (the current Mist request and an optional upgrade response). It is used by
//// the Mist handler, WebSocket, and SSE modules to coordinate HTTP → WebSocket
//// and HTTP → SSE upgrades and should not be used directly by application code.

import gleam/dynamic.{type Dynamic}
import gleam/erlang/atom.{type Atom}

pub const request_key = "dream_mist_request"

pub const response_key = "dream_mist_response"

@external(erlang, "erlang", "put")
pub fn put(key: Atom, value: Dynamic) -> Dynamic

@external(erlang, "erlang", "get")
pub fn get(key: Atom) -> Dynamic

@external(erlang, "gleam_stdlib", "identity")
pub fn to_dynamic(a: a) -> Dynamic

@external(erlang, "gleam_stdlib", "identity")
pub fn unsafe_coerce(a: a) -> b
