import exception
import gleam/bytes_tree.{type BytesTree}
import gleam/erlang/atom
import gleam/erlang/process.{type Subject}
import gleam/http as ghttp
import gleam/http/request.{type Request}
import gleam/http/response
import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import glisten/internal/handler.{Close, Internal}
import glisten/socket.{type Socket, type SocketReason, Badarg}
import glisten/transport.{type Transport}
import logging
import mist/internal/encoder
import mist/internal/file
import mist/internal/http.{
  type Connection, type Handler, type ResponseData, Bytes, Chunked, File,
  ServerSentEvents, Websocket,
}

pub type State {
  State(idle_timer: Option(process.Timer))
}

pub fn initial_state() -> State {
  State(idle_timer: None)
}

pub fn call(
  req: Request(Connection),
  handler: Handler,
  sender: Subject(handler.Message(user_message)),
  version: http.HttpVersion,
) -> Result(State, Result(Nil, String)) {
  exception.rescue(fn() { handler(req) })
  |> result.map_error(log_and_error(
    _,
    req.body.socket,
    req.body.transport,
    req,
    version,
  ))
  |> result.try(fn(resp) {
    case resp {
      response.Response(body: Websocket, ..)
      | response.Response(body: ServerSentEvents, ..)
      | response.Response(body: Chunked, ..) -> {
        Error(Ok(Nil))
      }
      response.Response(body: body, ..) as resp -> {
        case body {
          Bytes(body) ->
            handle_bytes_tree_body(resp, body, req.body, req, version)
          File(..) -> handle_file_body(resp, body, req.body, version)
          _ -> panic as "This shouldn't ever happen 🤞"
        }
        |> result.replace_error(Ok(Nil))
        |> result.try(close_or_set_timer(_, req.body, sender))
      }
    }
  })
}

fn log_and_error(
  error: exception.Exception,
  socket: Socket,
  transport: Transport,
  req: Request(Connection),
  version: http.HttpVersion,
) -> Result(Nil, String) {
  let error_string = string.inspect(error)
  logging.log(logging.Error, error_string)
  let resp =
    response.new(500)
    |> response.set_body(
      bytes_tree.from_bit_array(<<"Internal Server Error":utf8>>),
    )
    |> response.prepend_header("content-length", "21")
    |> http.add_default_headers(req.method == ghttp.Head)

  let resp = case version {
    http.Http1 -> http.connection_close(resp)
    _ -> http.maybe_keep_alive(resp)
  }

  let _ =
    resp
    |> encoder.to_bytes_tree(http.version_to_string(version))
    |> transport.send(transport, socket, _)

  lingering_close(transport, socket)
  Error(error_string)
}

fn close_or_set_timer(
  resp: response.Response(BytesTree),
  conn: Connection,
  sender: Subject(handler.Message(user_message)),
) -> Result(State, Result(Nil, String)) {
  // If the handler explicitly says to close the connection, we should
  // probably listen to them
  case response.get_header(resp, "connection") {
    Ok("close") -> {
      lingering_close(conn.transport, conn.socket)
      Error(Ok(Nil))
    }
    _ -> {
      // TODO:  this should be a configuration
      let timer = process.send_after(sender, 10_000, Internal(Close))
      Ok(State(idle_timer: Some(timer)))
    }
  }
}

/// How long, in milliseconds, `lingering_close` keeps reading from a
/// connection before it closes the socket anyway.
const lingering_close_budget_ms = 5000

/// Close an HTTP/1 connection in stages, as RFC 9112 section 9.6 asks.
///
/// Closing a socket while the client is still sending (for example after a
/// 413 that was answered before the request body was read) makes the kernel
/// send a TCP reset instead of a normal close, and the reset can erase the
/// response before the client has read it. So we first half-close the write
/// side, which tells the client that the response is complete, then read and
/// discard whatever the client still sends until it closes its side or the
/// time budget is spent, and only then close the socket.
fn lingering_close(transport: Transport, socket: Socket) -> Nil {
  let _ = transport.shutdown(transport, socket)
  drain_until(transport, socket, now_ms() + lingering_close_budget_ms)
  let _ = transport.close(transport, socket)
  Nil
}

fn drain_until(transport: Transport, socket: Socket, deadline: Int) -> Nil {
  let remaining = deadline - now_ms()
  case remaining > 0 {
    False -> Nil
    True ->
      case transport.receive_timeout(transport, socket, 0, remaining) {
        Ok(_discarded) -> drain_until(transport, socket, deadline)
        Error(_closed_or_timed_out) -> Nil
      }
  }
}

@external(erlang, "erlang", "monotonic_time")
fn monotonic_time(unit: atom.Atom) -> Int

fn now_ms() -> Int {
  monotonic_time(atom.create("millisecond"))
}

fn handle_file_body(
  resp: response.Response(ResponseData),
  body: ResponseData,
  conn: Connection,
  http_version: http.HttpVersion,
) -> Result(response.Response(BytesTree), SocketReason) {
  let assert File(file_descriptor, offset, length) = body
  let resp =
    resp
    |> response.set_body(bytes_tree.new())
    |> http.add_date_header
    |> response.prepend_header("content-length", int.to_string(length))

  let resp = case http_version {
    http.Http1 -> http.connection_close(resp)
    _ -> http.maybe_keep_alive(resp)
  }

  let return =
    resp
    |> fn(r: response.Response(BytesTree)) {
      encoder.response_builder(
        resp.status,
        r.headers,
        http.version_to_string(http_version),
      )
    }
    |> transport.send(conn.transport, conn.socket, _)
    |> result.try(fn(_) {
      file.sendfile(
        conn.transport,
        file_descriptor,
        conn.socket,
        offset,
        length,
        [],
      )
      |> result.map_error(fn(err) {
        logging.log(
          logging.Error,
          "Failed to send file: " <> string.inspect(err),
        )
        Badarg
      })
    })
    |> result.replace(resp)

  case file.close(file_descriptor) {
    Ok(_nil) -> Nil
    Error(reason) -> {
      logging.log(
        logging.Error,
        "Failed to close file: " <> file.error_to_string(reason),
      )
    }
  }

  return
}

fn handle_bytes_tree_body(
  resp: response.Response(ResponseData),
  body: BytesTree,
  conn: Connection,
  req: Request(Connection),
  version: http.HttpVersion,
) -> Result(response.Response(BytesTree), SocketReason) {
  let resp =
    resp
    |> response.set_body(body)
    |> http.add_default_headers(req.method == ghttp.Head)

  let resp = case version {
    http.Http1 -> http.connection_close(resp)
    _ -> http.maybe_keep_alive(resp)
  }

  resp
  |> encoder.to_bytes_tree(http.version_to_string(version))
  |> transport.send(conn.transport, conn.socket, _)
  |> result.replace(resp)
}
