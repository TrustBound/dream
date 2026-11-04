import gleam/bit_array
import gleam/dict.{type Dict}
import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import logging
import mist/internal/buffer.{type Buffer}
import mist/internal/http.{type Connection, type Handler, Connection, Initial}
import mist/internal/http2.{type HpackContext, type Http2Settings}
import mist/internal/http2/flow_control
import mist/internal/http2/frame.{
  type Frame, type StreamIdentifier, Complete, Continued,
}
import mist/internal/http2/stream.{type SendMessage, Ready}

pub type PendingSend {
  PendingSend
}

pub type State {
  State(
    fragment: Option(Frame),
    frame_buffer: Buffer,
    last_stream_id: StreamIdentifier(Frame),
    pending_sends: List(PendingSend),
    receive_hpack_context: HpackContext,
    self: Subject(SendMessage),
    send_hpack_context: HpackContext,
    send_window_size: Int,
    receive_window_size: Int,
    settings: Http2Settings,
    streams: Dict(StreamIdentifier(Frame), stream.State),
  )
}

pub fn send_hpack_context(state: State, context: HpackContext) -> State {
  State(..state, send_hpack_context: context)
}

pub fn receive_hpack_context(state: State, context: HpackContext) -> State {
  State(..state, receive_hpack_context: context)
}

pub fn append_data(state: State, data: BitArray) -> State {
  State(..state, frame_buffer: buffer.append(state.frame_buffer, data))
}

pub fn remove_stream(state: State, id: StreamIdentifier(Frame)) -> State {
  State(..state, streams: dict.delete(state.streams, id))
}

pub fn upgrade(
  data: BitArray,
  conn: Connection,
  self: Subject(SendMessage),
) -> Result(State, String) {
  let initial_settings = http2.default_settings()
  let settings_frame = frame.Settings(ack: False, settings: [])

  let sent =
    http2.send_frame(settings_frame, conn.socket, conn.transport)
    |> result.replace_error("Failed to send settings frame")

  use _nil <- result.map(sent)
  State(
    fragment: None,
    frame_buffer: buffer.new(data),
    last_stream_id: frame.stream_identifier(0),
    pending_sends: [],
    receive_hpack_context: http2.hpack_new_context(
      initial_settings.header_table_size,
    ),
    receive_window_size: 65_535,
    self: self,
    send_hpack_context: http2.hpack_new_context(
      initial_settings.header_table_size,
    ),
    send_window_size: 65_535,
    settings: initial_settings,
    streams: dict.new(),
  )
}

pub fn call(
  state: State,
  conn: Connection,
  handler: Handler,
) -> Result(State, Result(Nil, String)) {
  case frame.decode(state.frame_buffer.data) {
    Ok(#(frame, rest)) -> {
      let new_state = State(..state, frame_buffer: buffer.new(rest))
      case handle_frame(frame, new_state, conn, handler) {
        Ok(updated) -> call(updated, conn, handler)
        Error(reason) -> Error(Error(reason))
      }
    }
    Error(frame.NoError) -> Ok(state)
    Error(connection_error) -> {
      case bit_array.byte_size(state.frame_buffer.data) < 9 {
        True -> Ok(state)
        False -> {
          let goaway =
            frame.GoAway(
              data: <<>>,
              error: connection_error,
              last_stream_id: state.last_stream_id,
            )
          let _ = http2.send_frame(goaway, conn.socket, conn.transport)
          Error(Error("Connection error"))
        }
      }
    }
  }
}

// TODO:  this should use the frame error types to actually do some shit with
// the stream(s)
fn handle_frame(
  frame: Frame,
  state: State,
  conn: Connection,
  handler: Handler,
) -> Result(State, String) {
  case state.fragment, frame {
    Some(frame.Header(
      identifier: id1,
      data: Continued(existing),
      end_stream: end_stream,
      priority: priority,
    )),
      frame.Continuation(data: Complete(data), identifier: id2)
      if id1 == id2
    -> {
      let complete_frame =
        frame.Header(
          identifier: id1,
          data: Complete(<<existing:bits, data:bits>>),
          end_stream: end_stream,
          priority: priority,
        )
      handle_frame(
        complete_frame,
        State(..state, fragment: None),
        conn,
        handler,
      )
    }
    Some(frame.Header(
      identifier: id1,
      data: Continued(existing),
      end_stream: end_stream,
      priority: priority,
    )),
      frame.Continuation(data: Continued(data), identifier: id2)
      if id1 == id2
    -> {
      let next =
        frame.Header(
          identifier: id1,
          data: Continued(<<existing:bits, data:bits>>),
          end_stream: end_stream,
          priority: priority,
        )
      Ok(State(..state, fragment: Some(next)))
    }
    None, frame.WindowUpdate(amount, identifier) -> {
      case frame.get_stream_identifier(identifier) {
        0 -> {
          case flow_control.update_send_window(state.send_window_size, amount) {
            Ok(new_window) -> Ok(State(..state, send_window_size: new_window))
            _err -> Error("Connection flow control error")
          }
        }
        _stream_id -> {
          case dict.get(state.streams, identifier) {
            Error(Nil) -> Ok(state)
            Ok(stream) -> {
              case
                flow_control.update_send_window(stream.send_window_size, amount)
              {
                Ok(update) -> {
                  let new_stream =
                    stream.State(..stream, send_window_size: update)
                  Ok(
                    State(
                      ..state,
                      streams: dict.insert(
                        state.streams,
                        identifier,
                        new_stream,
                      ),
                    ),
                  )
                }
                _err -> {
                  let _ =
                    http2.send_frame(
                      frame.Termination(
                        error: frame.FlowControlError,
                        identifier: identifier,
                      ),
                      conn.socket,
                      conn.transport,
                    )
                  Ok(
                    State(
                      ..state,
                      streams: dict.delete(state.streams, identifier),
                    ),
                  )
                }
              }
            }
          }
        }
      }
    }
    None, frame.Header(Complete(data), _end_stream, identifier, _priority) -> {
      let conn = Connection(..conn, body: Initial(<<>>))
      let assert Ok(#(headers, context)) =
        http2.hpack_decode(state.receive_hpack_context, data)

      let pending_content_length =
        headers
        |> list.key_find("content-length")
        |> result.try(int.parse)
        |> option.from_result

      let assert Ok(new_stream) =
        stream.new(identifier, handler, headers, conn, state.self)
      process.send(new_stream.data, Ready)

      let stream_state =
        stream.State(
          id: identifier,
          state: stream.Open,
          subject: new_stream.data,
          receive_window_size: state.settings.initial_window_size,
          send_window_size: state.settings.initial_window_size,
          pending_content_length: pending_content_length,
        )
      let streams = dict.insert(state.streams, identifier, stream_state)
      Ok(
        State(
          ..state,
          receive_hpack_context: context,
          streams: streams,
          last_stream_id: identifier,
        ),
      )
    }
    None, frame.Data(identifier: identifier, data: data, end_stream: end_stream)
    -> {
      case dict.get(state.streams, identifier) {
        Error(Nil) -> {
          let _ =
            http2.send_frame(
              frame.Termination(
                error: frame.StreamClosed,
                identifier: identifier,
              ),
              conn.socket,
              conn.transport,
            )
          Ok(state)
        }
        Ok(stream) -> {
          let data_size = bit_array.byte_size(data)
          let #(conn_receive_window_size, conn_window_increment) =
            flow_control.compute_receive_window(
              state.receive_window_size,
              data_size,
            )
          let #(new_stream, increment) = stream.receive_data(stream, data_size)
          let _ = case conn_window_increment > 0 {
            True ->
              http2.send_frame(
                frame.WindowUpdate(
                  identifier: frame.stream_identifier(0),
                  amount: conn_window_increment,
                ),
                conn.socket,
                conn.transport,
              )
            False -> Ok(Nil)
          }
          let _ = case increment > 0 {
            True ->
              http2.send_frame(
                frame.WindowUpdate(identifier: identifier, amount: increment),
                conn.socket,
                conn.transport,
              )
            False -> Ok(Nil)
          }
          process.send(
            new_stream.subject,
            stream.Data(bits: data, end: end_stream),
          )
          Ok(
            State(
              ..state,
              streams: dict.insert(state.streams, identifier, new_stream),
              receive_window_size: conn_receive_window_size,
            ),
          )
        }
      }
    }
    None, frame.Priority(..) -> {
      Ok(state)
    }
    None, frame.Settings(ack: True, ..) -> {
      Ok(state)
    }
    _, frame.Settings(ack: False, settings: settings_list) -> {
      let old_settings = state.settings
      let new_settings = http2.update_settings(old_settings, settings_list)
      let delta =
        new_settings.initial_window_size - old_settings.initial_window_size
      let max_window = int.bitwise_shift_left(1, 31) - 1

      let new_streams = case delta != 0 {
        True -> {
          let adjusted =
            dict.map_values(state.streams, fn(_id, s) {
              stream.State(..s, send_window_size: s.send_window_size + delta)
            })
          let overflow =
            dict.fold(adjusted, False, fn(acc, _id, s) {
              acc || s.send_window_size > max_window
            })
          case overflow {
            True -> {
              let goaway =
                frame.GoAway(
                  data: <<>>,
                  error: frame.FlowControlError,
                  last_stream_id: state.last_stream_id,
                )
              let _ = http2.send_frame(goaway, conn.socket, conn.transport)
              Error("Flow control window overflow from settings")
            }
            False -> Ok(adjusted)
          }
        }
        False -> Ok(state.streams)
      }

      use new_streams <- result.try(new_streams)

      let new_send_context = case
        new_settings.header_table_size != old_settings.header_table_size
      {
        True ->
          http2.hpack_max_table_size(
            state.send_hpack_context,
            new_settings.header_table_size,
          )
        False -> state.send_hpack_context
      }

      http2.send_frame(frame.settings_ack(), conn.socket, conn.transport)
      |> result.replace(
        State(
          ..state,
          settings: new_settings,
          streams: new_streams,
          send_hpack_context: new_send_context,
        ),
      )
      |> result.replace_error("Failed to respond to settings ACK")
    }
    None, frame.Ping(ack: False, data: data) -> {
      http2.send_frame(
        frame.Ping(ack: True, data: data),
        conn.socket,
        conn.transport,
      )
      |> result.replace(state)
      |> result.replace_error("Failed to send PING ACK")
    }
    None, frame.Ping(ack: True, ..) -> {
      Ok(state)
    }
    None, frame.Termination(identifier: identifier, ..) -> {
      Ok(State(..state, streams: dict.delete(state.streams, identifier)))
    }
    None, frame.GoAway(..) -> {
      logging.log(logging.Info, "Received GOAWAY, closing connection")
      Error("Going away...")
    }
    _, frame -> {
      logging.log(logging.Debug, "Ignoring frame: " <> string.inspect(frame))
      Ok(state)
    }
  }
}
