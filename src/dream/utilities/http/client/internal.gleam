//// Internal utilities for HTTP client
////
//// This module provides internal utilities for the HTTP client, including
//// Erlang externals and low-level stream handling.

import gleam/dynamic/decode as d
import gleam/erlang/atom
import gleam/erlang/process
import gleam/http
import gleam/http/request.{type Request}
import gleam/result
import gleam/string

// Erlang externals for streaming HTTP requests
@external(erlang, "dream_httpc_shim", "request_stream")
fn request_stream(
  method: atom.Atom,
  url: String,
  headers: List(#(String, String)),
  body: BitArray,
  receiver: process.Pid,
) -> d.Dynamic

@external(erlang, "dream_httpc_shim", "fetch_next")
fn fetch_next(owner: d.Dynamic) -> d.Dynamic

/// Convert an HTTP method to an Erlang atom
pub fn atomize_method(method: http.Method) -> atom.Atom {
  case method {
    http.Get -> atom.create("get")
    http.Post -> atom.create("post")
    http.Put -> atom.create("put")
    http.Delete -> atom.create("delete")
    http.Patch -> atom.create("patch")
    http.Head -> atom.create("head")
    http.Options -> atom.create("options")
    http.Trace -> atom.create("trace")
    http.Connect -> atom.create("connect")
    http.Other(method_string) -> atom.create(string.lowercase(method_string))
  }
}

/// Start an HTTP streaming request
pub fn start_httpc_stream(req: Request(String)) -> d.Dynamic {
  let url = http.scheme_to_string(req.scheme) <> "://" <> req.host <> req.path
  let method_atom = atomize_method(req.method)
  let body = <<req.body:utf8>>
  let me = process.self()
  request_stream(method_atom, url, req.headers, body, me)
}

/// Extract the owner PID from the request result
pub fn extract_owner_pid(request_result: d.Dynamic) -> d.Dynamic {
  // Expect {ok, OwnerPid}
  let decoded = d.run(request_result, d.at([1], d.dynamic))
  case decoded {
    Ok(id) -> id
    Error(_) -> request_result
  }
}

/// Receive the next chunk from the stream
pub fn receive_next(owner: d.Dynamic) -> Result(BitArray, Nil) {
  let resp = fetch_next(owner)
  let tag =
    d.run(resp, d.at([0], d.dynamic))
    |> result.try(fn(dyn) { Ok(atom.cast_from_dynamic(dyn)) })
    |> result.unwrap(atom.create(""))
    |> atom.to_string
  case tag {
    "chunk" -> {
      let bin = d.run(resp, d.at([1], d.bit_array)) |> result.unwrap(<<>>)
      Ok(bin)
    }
    "finished" -> Error(Nil)
    _ -> Error(Nil)
  }
}
