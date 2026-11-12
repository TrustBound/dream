import gleam/bytes_tree
import gleam/dict
import gleam/erlang/process.{type Selector, type Subject}
import gleam/http/response
import gleam/int
import gleam/option.{type Option, Some}
import gleam/otp/actor
import gleam/otp/factory_supervisor as factory
import gleam/result
import glisten.{type Loop, Packet, User}
import glisten/transport
import logging
import mist/internal/encoder
import mist/internal/http.{
  type DecodeError, type Handler, Bytes, Chunked, Connection, DiscardPacket,
  File, Initial, ServerSentEvents, Websocket,
}
import mist/internal/http/handler as http_handler
import mist/internal/http2
import mist/internal/http2/frame
import mist/internal/http2/handler as http2_handler
import mist/internal/http2/stream.{
  type SendMessage, ConsumeData, Reset, Send, SendData, SendHeaders,
}

pub type HandlerError {
  InvalidRequest(DecodeError)
  NotFound
}

pub type State {
  Http1(state: http_handler.State, self: Subject(SendMessage))
  Http2(state: http2_handler.State)
}

pub fn new_state(subj: Subject(SendMessage)) -> State {
  Http1(http_handler.initial_state(), subj)
}

pub fn init(_conn) -> #(State, Option(Selector(SendMessage))) {
  let subj = process.new_subject()
  let selector =
    process.new_selector()
    |> process.select(subj)

  #(new_state(subj), Some(selector))
}

pub fn with_func(
  handler: Handler,
  factory_name: process.Name(
    factory.Message(
      fn() -> Result(actor.Started(process.Pid), actor.StartError),
      process.Pid,
    ),
  ),
  read_timeout: Int,
  send_timeout: Int,
) -> Loop(State, SendMessage) {
  fn(state: State, msg, conn: glisten.Connection(SendMessage)) {
    let sender = conn.subject
    let conn =
      Connection(
        body: Initial(<<>>),
        socket: conn.socket,
        transport: conn.transport,
        factory_name:,
        read_timeout:,
      )

    let result = case msg, state {
      User(_msg), Http1(..) -> {
        Error(Error("Attempted to send HTTP/2 response without upgrade"))
      }
      User(Send(id, resp)), Http2(state) -> {
        case resp.body {
          Bytes(bytes) ->
            case
              dict.has_key(state.streams, id),
              http2_handler.headers_sent(state, id)
            {
              False, _ -> Ok(state)
              True, True ->
                http2_handler.reset_stream(state, conn, id, frame.InternalError)
              True, False -> {
                resp
                |> response.set_body(bytes)
                |> http2.encode_response(
                  state.send_hpack_context,
                  id,
                  state.settings.max_frame_size,
                )
                |> result.try(fn(pair) {
                  let #(headers, context) = pair
                  let state = http2_handler.send_hpack_context(state, context)
                  case bytes_tree.to_bit_array(bytes) {
                    <<>> ->
                      http2.send_encoded(conn, headers)
                      |> result.try(fn(_nil) {
                        http2_handler.close_stream(state, conn, id)
                      })
                    data ->
                      http2_handler.send_response(
                        state,
                        conn,
                        id,
                        headers,
                        data,
                      )
                  }
                })
              }
            }
          File(..) -> Error("File sending unsupported over HTTP/2")
          // TODO:  properly error in some fashion for these
          Websocket -> Error("WebSocket unsupported for HTTP/2")
          Chunked -> http2_handler.send_data(state, conn, id, <<>>, True)
          ServerSentEvents ->
            http2_handler.send_data(state, conn, id, <<>>, True)
        }
        |> result.map(Http2)
        |> result.map_error(fn(err) {
          logging.log(logging.Debug, "Error sending HTTP/2 data: " <> err)
          Error(err)
        })
      }
      User(SendHeaders(id, status, headers)), Http2(state) -> {
        case dict.has_key(state.streams, id) {
          False -> Ok(Http2(state))
          True ->
            [#(":status", int.to_string(status)), ..headers]
            |> http2.send_headers(
              state.send_hpack_context,
              conn,
              _,
              False,
              id,
              state.settings.max_frame_size,
            )
            |> result.map(fn(context) {
              state
              |> http2_handler.send_hpack_context(context)
              |> http2_handler.set_headers_sent(id)
              |> Http2
            })
            |> result.map_error(Error)
        }
      }
      User(SendData(id, data, sent)), Http2(state) -> {
        state
        |> http2_handler.send_data_reply(conn, id, data, sent)
        |> result.map(Http2)
        |> result.map_error(Error)
      }
      User(ConsumeData(id, size)), Http2(state) -> {
        state
        |> http2_handler.consume_data(conn, id, size)
        |> result.map(Http2)
        |> result.map_error(Error)
      }
      User(Reset(id, error)), Http2(state) -> {
        state
        |> http2_handler.reset_stream(conn, id, error)
        |> result.map(Http2)
        |> result.map_error(Error)
      }
      Packet(msg), Http1(state, self) -> {
        let _ = case state.idle_timer {
          Some(t) -> process.cancel_timer(t)
          _ -> process.TimerNotFound
        }
        msg
        |> http.parse_request(conn)
        |> result.map_error(fn(err) {
          case err {
            DiscardPacket -> Ok(Nil)
            http.MalformedRequest -> {
              let msg = "Received malformed HTTP request"
              logging.log(logging.Warning, msg)
              Error(msg)
            }
            http.InvalidMethod -> {
              let msg = "Received invalid HTTP method"
              logging.log(logging.Warning, msg)
              Error(msg)
            }
            http.InvalidPath -> {
              let msg = "Received invalid HTTP path"
              logging.log(logging.Warning, msg)
              Error(msg)
            }
            http.UnknownHeader -> {
              let msg = "Received unknown HTTP header"
              logging.log(logging.Warning, msg)
              Error(msg)
            }
            http.UnknownMethod -> {
              let msg = "Received unknown HTTP method"
              logging.log(logging.Warning, msg)
              Error(msg)
            }
            http.InvalidBody | http.ExcessBody -> {
              let msg = "Received invalid HTTP body"
              logging.log(logging.Warning, msg)
              Error(msg)
            }
            http.NoHostHeader -> {
              let msg = "Missing HTTP `host` header"
              logging.log(logging.Warning, msg)
              let _ =
                response.new(400)
                |> response.prepend_header("connection", "close")
                |> response.set_body(bytes_tree.new())
                |> encoder.to_bytes_tree("1.1")
                |> transport.send(conn.transport, conn.socket, _)
              Ok(Nil)
            }
            http.InvalidHttpVersion -> {
              let msg = "Received invalid HTTP version"
              logging.log(logging.Warning, msg)
              Error(msg)
            }
          }
        })
        |> result.try(fn(req) {
          case req {
            http.Http1Request(req, version) ->
              http_handler.call(req, handler, sender, version)
              |> result.map(fn(new_state) {
                Http1(state: new_state, self: self)
              })
            http.Upgrade(data) ->
              http2_handler.upgrade(data, conn, self, send_timeout)
              |> result.map_error(Error)
              |> result.try(fn(state) {
                http2_handler.call(state, conn, handler)
              })
              |> result.map(Http2)
          }
        })
      }
      Packet(msg), Http2(state) -> {
        state
        |> http2_handler.append_data(msg)
        |> http2_handler.call(conn, handler)
        |> result.map(Http2)
      }
    }

    case result {
      Ok(value) -> glisten.continue(value)
      Error(Ok(_nil)) -> glisten.stop()
      Error(Error(reason)) -> glisten.stop_abnormal(reason)
    }
  }
}
