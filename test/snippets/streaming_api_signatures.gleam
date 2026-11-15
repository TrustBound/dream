//// Streaming API reference: function signatures
////
//// Each constant holds a real Dream function under its full type, so the
//// tests fail when a signature changes.

import dream/dream.{type Dream}
import dream/http/request.{type Method, type Request}
import dream/http/response.{type Response}
import dream/router.{type Router}
import dream/servers/mist/server
import dream/servers/mist/sse.{type Action, type Event, type SSEConnection}
import gleam/erlang/process.{type Selector, type Subject}
import gleam/option.{type Option}
import gleam/yielder.{type Yielder}
import mist.{type Builder, type Connection, type ResponseData}

pub const stream_response: fn(Int, Yielder(BitArray), String) -> Response = response.stream_response

pub const sse_response: fn(Int, Yielder(BitArray), String) -> Response = response.sse_response

pub const upgrade_to_sse: fn(
  Request,
  deps,
  fn(Subject(message), deps) -> #(state, Option(Selector(message))),
  fn(state, message, SSEConnection, deps) -> Action(state, message),
) -> Response = sse.upgrade_to_sse

pub const send_event: fn(SSEConnection, Event) -> Result(Nil, Nil) = sse.send_event

pub const event: fn(String) -> Event = sse.event

pub const event_name: fn(Event, String) -> Event = sse.event_name

pub const event_id: fn(Event, String) -> Event = sse.event_id

pub const event_retry: fn(Event, Int) -> Event = sse.event_retry

pub const continue_connection: fn(state) -> Action(state, message) = sse.continue_connection

pub const continue_connection_with_selector: fn(state, Selector(message)) ->
  Action(state, message) = sse.continue_connection_with_selector

pub const stop_connection: fn() -> Action(state, message) = sse.stop_connection

pub const stream_route: fn(
  Router(context, services),
  Method,
  String,
  fn(Request, context, services) -> Response,
  List(
    fn(Request, context, services, fn(Request, context, services) -> Response) ->
      Response,
  ),
) -> Router(context, services) = router.stream_route

pub const route: fn(
  Router(context, services),
  Method,
  String,
  fn(Request, context, services) -> Response,
  List(
    fn(Request, context, services, fn(Request, context, services) -> Response) ->
      Response,
  ),
) -> Router(context, services) = router.route

pub const max_body_size: fn(
  Dream(Builder(Connection, ResponseData), context, services),
  Int,
) -> Dream(Builder(Connection, ResponseData), context, services) = server.max_body_size
