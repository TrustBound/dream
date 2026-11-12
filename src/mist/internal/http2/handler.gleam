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
  PendingSend(
    identifier: StreamIdentifier(Frame),
    data: BitArray,
    end: Bool,
    sent: Option(Subject(Result(Nil, Nil))),
  )
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
    send_timeout: Int,
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

pub fn close_stream(
  state: State,
  conn: Connection,
  id: StreamIdentifier(Frame),
) -> Result(State, String) {
  case dict.get(state.streams, id) {
    Ok(stream.State(state: stream.RemoteClosed, ..)) ->
      Ok(State(..state, streams: dict.delete(state.streams, id)))
    Ok(_stream) -> reset_stream(state, conn, id, frame.NoError)
    Error(_nil) -> Ok(state)
  }
}

pub fn headers_sent(state: State, id: StreamIdentifier(Frame)) -> Bool {
  state.streams
  |> dict.get(id)
  |> result.map(fn(stream) { stream.headers_sent })
  |> result.unwrap(False)
}

pub fn set_headers_sent(state: State, id: StreamIdentifier(Frame)) -> State {
  case dict.get(state.streams, id) {
    Ok(stream) -> {
      let new_stream = stream.State(..stream, headers_sent: True)
      State(..state, streams: dict.insert(state.streams, id, new_stream))
    }
    Error(_nil) -> state
  }
}

pub fn reset_stream(
  state: State,
  conn: Connection,
  id: StreamIdentifier(Frame),
  error: frame.ConnectionError,
) -> Result(State, String) {
  frame.Termination(error: error, identifier: id)
  |> http2.send_frame(conn.socket, conn.transport)
  |> result.replace(remove_stream(state, id))
  |> result.replace_error("Failed to reset stream")
}

fn remove_stream(state: State, id: StreamIdentifier(Frame)) -> State {
  let _ =
    state.streams
    |> dict.get(id)
    |> result.try(fn(stream) { process.subject_owner(stream.subject) })
    |> result.map(fn(pid) {
      process.unlink(pid)
      process.kill(pid)
    })
  let #(removed, pending_sends) =
    list.partition(state.pending_sends, fn(pending) { pending.identifier == id })
  list.each(removed, fn(pending) { reply(pending.sent, Error(Nil)) })
  State(
    ..state,
    pending_sends: pending_sends,
    streams: dict.delete(state.streams, id),
  )
}

fn reply(
  sent: Option(Subject(Result(Nil, Nil))),
  result: Result(Nil, Nil),
) -> Nil {
  case sent {
    Some(sent) -> process.send(sent, result)
    None -> Nil
  }
}

pub fn send_data(
  state: State,
  conn: Connection,
  id: StreamIdentifier(Frame),
  data: BitArray,
  end: Bool,
) -> Result(State, String) {
  send_frames(state, conn, id, <<>>, data, end, None)
}

pub fn send_data_reply(
  state: State,
  conn: Connection,
  id: StreamIdentifier(Frame),
  data: BitArray,
  sent: Subject(Result(Nil, Nil)),
) -> Result(State, String) {
  send_frames(state, conn, id, <<>>, data, False, Some(sent))
}

pub fn send_response(
  state: State,
  conn: Connection,
  id: StreamIdentifier(Frame),
  headers: BitArray,
  data: BitArray,
) -> Result(State, String) {
  send_frames(state, conn, id, headers, data, True, None)
}

fn send_frames(
  state: State,
  conn: Connection,
  id: StreamIdentifier(Frame),
  before: BitArray,
  data: BitArray,
  end: Bool,
  sent: Option(Subject(Result(Nil, Nil))),
) -> Result(State, String) {
  let queued =
    list.any(state.pending_sends, fn(pending) { pending.identifier == id })
  case dict.get(state.streams, id) {
    Error(_nil) -> {
      reply(sent, Error(Nil))
      Ok(state)
    }
    Ok(stream) -> {
      let size =
        flow_control.compute_send_size(
          stream.send_window_size,
          state.send_window_size,
          bit_array.byte_size(data),
        )
      case size > 0 || data == <<>>, queued {
        True, False -> {
          let assert <<data:bytes-size(size), rest:bytes>> = data
          let end_stream = end && rest == <<>>
          let written =
            http2.send_body(
              conn,
              before,
              data,
              id,
              end_stream,
              state.settings.max_frame_size,
            )
          use _nil <- result.try(written)
          let stream =
            stream.State(
              ..stream,
              send_window_size: stream.send_window_size - size,
            )
          let state =
            State(
              ..state,
              send_window_size: state.send_window_size - size,
              streams: dict.insert(state.streams, id, stream),
            )
          case end_stream, rest {
            True, _ -> {
              reply(sent, Ok(Nil))
              close_stream(state, conn, id)
            }
            False, <<>> -> {
              reply(sent, Ok(Nil))
              Ok(state)
            }
            False, _ -> {
              let pending =
                PendingSend(identifier: id, data: rest, end: end, sent: sent)
              Ok(
                State(..state, pending_sends: [pending, ..state.pending_sends]),
              )
            }
          }
        }
        _, _ -> {
          use _nil <- result.map(http2.send_encoded(conn, before))
          let pending =
            PendingSend(identifier: id, data: data, end: end, sent: sent)
          State(..state, pending_sends: [pending, ..state.pending_sends])
        }
      }
    }
  }
}

const window_update_threshold = 32_768

pub fn consume_data(
  state: State,
  conn: Connection,
  id: StreamIdentifier(Frame),
  size: Int,
) -> Result(State, String) {
  case dict.get(state.streams, id) {
    Ok(stream.State(state: stream.RemoteClosed, ..)) | Error(_nil) -> Ok(state)
    Ok(stream) -> {
      let consumed = stream.consumed_size + size
      case consumed >= window_update_threshold {
        True -> {
          let stream =
            stream.State(
              ..stream,
              receive_window_size: stream.receive_window_size + consumed,
              consumed_size: 0,
            )
          frame.WindowUpdate(identifier: id, amount: consumed)
          |> http2.send_frame(conn.socket, conn.transport)
          |> result.replace(
            State(..state, streams: dict.insert(state.streams, id, stream)),
          )
          |> result.replace_error("Failed to send window update")
        }
        False -> {
          let stream = stream.State(..stream, consumed_size: consumed)
          Ok(State(..state, streams: dict.insert(state.streams, id, stream)))
        }
      }
    }
  }
}

fn do_pending_sends(state: State, conn: Connection) -> Result(State, String) {
  state.pending_sends
  |> list.reverse
  |> list.try_fold(State(..state, pending_sends: []), fn(state, pending) {
    send_frames(
      state,
      conn,
      pending.identifier,
      <<>>,
      pending.data,
      pending.end,
      pending.sent,
    )
  })
}

pub fn append_data(state: State, data: BitArray) -> State {
  State(..state, frame_buffer: buffer.append(state.frame_buffer, data))
}

pub fn upgrade(
  data: BitArray,
  conn: Connection,
  self: Subject(SendMessage),
  send_timeout: Int,
) -> Result(State, String) {
  let initial_settings = http2.default_settings()
  let settings_frame =
    frame.Settings(ack: False, settings: [
      frame.MaxConcurrentStreams(initial_settings.max_concurrent_streams),
    ])

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
    send_timeout: send_timeout,
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
    Ok(#(frame.GoAway(..), _rest)) -> Error(Ok(Nil))
    Ok(#(frame, rest)) -> {
      let new_state = State(..state, frame_buffer: buffer.new(rest))
      let length =
        bit_array.byte_size(state.frame_buffer.data)
        - bit_array.byte_size(rest)
        - 9
      case handle_frame(frame, length, new_state, conn, handler) {
        Ok(updated) -> call(updated, conn, handler)
        Error(reason) -> Error(Error(reason))
      }
    }
    Error(frame.NoError) -> Ok(state)
    Error(error) -> {
      case bit_array.byte_size(state.frame_buffer.data) < 9 {
        True -> Ok(state)
        False -> {
          let _ = send_go_away(state, conn, error)
          Error(Error("Received malformed HTTP/2 frame"))
        }
      }
    }
  }
}

fn send_go_away(
  state: State,
  conn: Connection,
  error: frame.ConnectionError,
) -> Result(Nil, String) {
  frame.GoAway(data: <<>>, error: error, last_stream_id: state.last_stream_id)
  |> http2.send_frame(conn.socket, conn.transport)
  |> result.replace_error("Failed to send go away")
}

const max_header_block_size = 65_536

fn append_fragment(
  state: State,
  conn: Connection,
  existing: BitArray,
  data: BitArray,
) -> Result(BitArray, String) {
  let block = <<existing:bits, data:bits>>
  case bit_array.byte_size(block) > max_header_block_size {
    True -> {
      let _ = send_go_away(state, conn, frame.EnhanceYourCalm)
      Error("Received an HTTP/2 header block that is too large")
    }
    False -> Ok(block)
  }
}

fn receive_trailers(
  state: State,
  conn: Connection,
  context: HpackContext,
  identifier: StreamIdentifier(Frame),
  end_stream: Bool,
  next: fn() -> Result(State, String),
) -> Result(State, String) {
  let state = State(..state, receive_hpack_context: context)
  let id = frame.get_stream_identifier(identifier)
  let last_id = frame.get_stream_identifier(state.last_stream_id)
  case dict.get(state.streams, identifier), end_stream {
    Error(_nil), _ if id > last_id && id % 2 == 1 -> next()
    Error(_nil), _ -> {
      let _ = send_go_away(state, conn, frame.ProtocolError)
      Error("Received an unexpected HTTP/2 stream identifier")
    }
    Ok(stream.State(state: stream.RemoteClosed, ..)), _ ->
      reset_stream(state, conn, identifier, frame.StreamClosed)
    Ok(_stream), False ->
      reset_stream(state, conn, identifier, frame.ProtocolError)
    Ok(stream.State(pending_content_length: Some(remaining), ..)), True
      if remaining != 0
    -> reset_stream(state, conn, identifier, frame.ProtocolError)
    Ok(stream), True -> {
      process.send(stream.subject, stream.Data(bits: <<>>, end: True))
      let streams =
        dict.insert(
          state.streams,
          identifier,
          stream.State(..stream, state: stream.RemoteClosed),
        )
      Ok(State(..state, streams: streams))
    }
  }
}

fn check_content_length(
  state: State,
  conn: Connection,
  identifier: StreamIdentifier(Frame),
  size: Int,
  end_stream: Bool,
  next: fn() -> Result(State, String),
) -> Result(State, String) {
  case dict.get(state.streams, identifier), end_stream {
    Ok(stream.State(state: stream.RemoteClosed, ..)), _ ->
      reset_stream(state, conn, identifier, frame.StreamClosed)
    Ok(stream.State(pending_content_length: Some(remaining), ..)), True
      if remaining != size
    -> reset_stream(state, conn, identifier, frame.ProtocolError)
    _, _ -> next()
  }
}

fn check_receive_window(
  state: State,
  conn: Connection,
  identifier: StreamIdentifier(Frame),
  size: Int,
  next: fn() -> Result(State, String),
) -> Result(State, String) {
  case dict.get(state.streams, identifier) {
    Ok(stream) if size > stream.receive_window_size ->
      reset_stream(state, conn, identifier, frame.FlowControlError)
    _ -> next()
  }
}

fn check_concurrent_streams(
  state: State,
  conn: Connection,
  identifier: StreamIdentifier(Frame),
  next: fn() -> Result(State, String),
) -> Result(State, String) {
  let max_streams = http2.default_settings().max_concurrent_streams
  case dict.size(state.streams) >= max_streams {
    True -> reset_stream(state, conn, identifier, frame.RefusedStream)
    False -> next()
  }
}

fn check_empty_body(
  state: State,
  conn: Connection,
  identifier: StreamIdentifier(Frame),
  content_length: Option(Int),
  end_stream: Bool,
  next: fn() -> Result(State, String),
) -> Result(State, String) {
  case content_length, end_stream {
    Some(length), True if length != 0 ->
      reset_stream(state, conn, identifier, frame.ProtocolError)
    _, _ -> next()
  }
}

fn handle_frame(
  frame: Frame,
  length: Int,
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
      use block <- result.try(append_fragment(state, conn, existing, data))
      let complete_frame =
        frame.Header(
          identifier: id1,
          data: Complete(block),
          end_stream: end_stream,
          priority: priority,
        )
      handle_frame(
        complete_frame,
        length,
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
      use block <- result.try(append_fragment(state, conn, existing, data))
      let next =
        frame.Header(
          identifier: id1,
          data: Continued(block),
          end_stream: end_stream,
          priority: priority,
        )
      Ok(State(..state, fragment: Some(next)))
    }
    Some(_fragment), _frame -> {
      let _ = send_go_away(state, conn, frame.ProtocolError)
      Error("Received a frame inside an HTTP/2 header block")
    }
    None, frame.Header(data: Continued(_data), ..) -> {
      Ok(State(..state, fragment: Some(frame)))
    }
    None, frame.Continuation(..) -> {
      let _ = send_go_away(state, conn, frame.ProtocolError)
      Error("Received an HTTP/2 continuation without a header block")
    }
    None, frame.WindowUpdate(amount, identifier) -> {
      case frame.get_stream_identifier(identifier) {
        0 -> {
          flow_control.update_send_window(state.send_window_size, amount)
          |> result.replace_error("Failed to update send window")
          |> result.map(fn(size) { State(..state, send_window_size: size) })
          |> result.try(do_pending_sends(_, conn))
        }
        _stream_id -> {
          state.streams
          |> dict.get(identifier)
          |> result.map(fn(stream) {
            case
              flow_control.update_send_window(stream.send_window_size, amount)
            {
              Ok(update) -> {
                let new_stream =
                  stream.State(..stream, send_window_size: update)
                Ok(
                  State(
                    ..state,
                    streams: dict.insert(state.streams, identifier, new_stream),
                  ),
                )
              }
              _err -> Error("Failed to update send window")
            }
          })
          |> result.unwrap(Ok(state))
          |> result.try(do_pending_sends(_, conn))
        }
      }
    }
    None, frame.Header(Complete(data), end_stream, identifier, _priority) -> {
      let conn = Connection(..conn, body: Initial(<<>>))
      let decoded =
        http2.hpack_decode(state.receive_hpack_context, data)
        |> result.map_error(fn(_hpack_error) {
          let _ = send_go_away(state, conn, frame.CompressionError)
          "Failed to decode HTTP/2 headers"
        })
      use #(headers, context) <- result.try(decoded)
      use <- receive_trailers(state, conn, context, identifier, end_stream)

      let pending_content_length =
        headers
        |> list.key_find("content-length")
        |> result.try(int.parse)
        |> option.from_result

      use <- check_concurrent_streams(
        State(
          ..state,
          last_stream_id: identifier,
          receive_hpack_context: context,
        ),
        conn,
        identifier,
      )
      use <- check_empty_body(
        State(
          ..state,
          last_stream_id: identifier,
          receive_hpack_context: context,
        ),
        conn,
        identifier,
        pending_content_length,
        end_stream,
      )
      let assert Ok(new_stream) =
        stream.new(
          identifier,
          handler,
          headers,
          conn,
          state.self,
          end_stream,
          state.send_timeout,
          // fn(resp) { process.send(state.self, Send(identifier, resp)) },
        )
      process.send(new_stream.data, Ready)

      let stream_state =
        stream.State(
          id: identifier,
          state: case end_stream {
            True -> stream.RemoteClosed
            False -> stream.Open
          },
          subject: new_stream.data,
          receive_window_size: 65_535,
          consumed_size: 0,
          send_window_size: state.settings.initial_window_size,
          pending_content_length: pending_content_length,
          headers_sent: False,
        )
      let streams = dict.insert(state.streams, identifier, stream_state)
      Ok(
        State(
          ..state,
          last_stream_id: identifier,
          receive_hpack_context: context,
          streams: streams,
        ),
      )
    }
    None, frame.Data(identifier: identifier, data: data, end_stream: end_stream)
    -> {
      let data_size = bit_array.byte_size(data)
      let #(conn_receive_window_size, conn_window_increment) =
        flow_control.compute_receive_window(state.receive_window_size, length)
      let _ = case conn_window_increment > 0 {
        True -> {
          http2.send_frame(
            frame.WindowUpdate(
              identifier: frame.stream_identifier(0),
              amount: conn_window_increment,
            ),
            conn.socket,
            conn.transport,
          )
        }
        False -> Ok(Nil)
      }

      use <- check_content_length(
        State(..state, receive_window_size: conn_receive_window_size),
        conn,
        identifier,
        data_size,
        end_stream,
      )
      use <- check_receive_window(
        State(..state, receive_window_size: conn_receive_window_size),
        conn,
        identifier,
        length,
      )
      state.streams
      |> dict.get(identifier)
      |> result.map(stream.receive_data(_, length, data_size))
      |> result.map(fn(new_stream) {
        process.send(
          new_stream.subject,
          stream.Data(bits: data, end: end_stream),
        )
        let streams = case end_stream {
          True ->
            dict.insert(
              state.streams,
              identifier,
              stream.State(..new_stream, state: stream.RemoteClosed),
            )
          False -> dict.insert(state.streams, identifier, new_stream)
        }
        State(
          ..state,
          streams: streams,
          receive_window_size: conn_receive_window_size,
        )
      })
      |> result.try_recover(fn(_nil) {
        State(..state, receive_window_size: conn_receive_window_size)
        |> reset_stream(conn, identifier, frame.StreamClosed)
      })
      |> result.try(consume_data(_, conn, identifier, length - data_size))
    }
    None, frame.Priority(..) -> {
      Ok(state)
    }
    None, frame.Settings(ack: True, ..) -> {
      Ok(state)
    }
    _, frame.Settings(settings: settings, ..) -> {
      let new_settings = http2.update_settings(state.settings, settings)
      let delta =
        new_settings.initial_window_size - state.settings.initial_window_size
      state.streams
      |> dict.to_list
      |> list.try_map(fn(pair) {
        let #(id, stream) = pair
        flow_control.update_send_window(stream.send_window_size, delta)
        |> result.map(fn(size) {
          #(id, stream.State(..stream, send_window_size: size))
        })
      })
      |> result.replace_error("Failed to update send window")
      |> result.try(fn(streams) {
        http2.send_frame(frame.settings_ack(), conn.socket, conn.transport)
        |> result.replace(
          State(
            ..state,
            send_hpack_context: http2.hpack_max_table_size(
              state.send_hpack_context,
              new_settings.header_table_size,
            ),
            settings: new_settings,
            streams: dict.from_list(streams),
          ),
        )
        |> result.replace_error("Failed to respond to settings ACK")
      })
      |> result.try(do_pending_sends(_, conn))
    }
    None, frame.Ping(ack: False, data: data) -> {
      http2.send_frame(
        frame.Ping(ack: True, data: data),
        conn.socket,
        conn.transport,
      )
      |> result.replace(state)
      |> result.replace_error("Failed to respond to ping")
    }
    None, frame.Termination(identifier: identifier, ..) -> {
      Ok(remove_stream(state, identifier))
    }
    // TODO:  obviously fill these out
    _, frame -> {
      logging.log(logging.Debug, "Ignoring frame: " <> string.inspect(frame))
      Ok(state)
    }
  }
}
