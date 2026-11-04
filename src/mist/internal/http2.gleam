import gleam/bit_array
import gleam/bytes_tree.{type BytesTree}
import gleam/http/response.{type Response}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import glisten/socket.{type Socket, type SocketReason}
import glisten/transport.{type Transport}
import logging
import mist/internal/http.{type Connection}
import mist/internal/http2/frame.{
  type Frame, type PushState, type Setting, type StreamIdentifier, Complete,
  Continued, Data, Header,
}

pub type Http2Settings {
  Http2Settings(
    header_table_size: Int,
    server_push: PushState,
    max_concurrent_streams: Int,
    initial_window_size: Int,
    max_frame_size: Int,
    max_header_list_size: Option(Int),
  )
}

pub fn default_settings() -> Http2Settings {
  Http2Settings(
    header_table_size: 4096,
    server_push: frame.Disabled,
    max_concurrent_streams: 100,
    initial_window_size: 65_535,
    max_frame_size: 16_384,
    max_header_list_size: None,
  )
}

pub fn update_settings(
  current: Http2Settings,
  settings: List(Setting),
) -> Http2Settings {
  list.fold(settings, current, fn(settings, setting) {
    case setting {
      frame.HeaderTableSize(size) ->
        Http2Settings(..settings, header_table_size: size)
      frame.ServerPush(push) -> Http2Settings(..settings, server_push: push)
      frame.MaxConcurrentStreams(max) ->
        Http2Settings(..settings, max_concurrent_streams: max)
      frame.InitialWindowSize(size) ->
        Http2Settings(..settings, initial_window_size: size)
      frame.MaxFrameSize(size) ->
        Http2Settings(..settings, max_frame_size: size)
      frame.MaxHeaderListSize(size) ->
        Http2Settings(..settings, max_header_list_size: Some(size))
    }
  })
}

pub fn send_headers(
  context: HpackContext,
  conn: Connection,
  headers: List(#(String, String)),
  end_stream: Bool,
  stream_identifier: StreamIdentifier(Frame),
  max_frame_size: Int,
) -> Result(HpackContext, String) {
  use pair <- result.try(hpack_encode(context, headers))
  let #(encoded_headers, new_context) = pair
  let header_size = bit_array.byte_size(encoded_headers)
  case header_size <= max_frame_size {
    True -> {
      let header_frame =
        Header(
          data: Complete(encoded_headers),
          end_stream: end_stream,
          identifier: stream_identifier,
          priority: None,
        )
      transport.send(
        conn.transport,
        conn.socket,
        bytes_tree.from_bit_array(frame.encode(header_frame)),
      )
      |> result.replace(new_context)
      |> result.map_error(fn(_) { "Failed to send HTTP/2 headers" })
    }
    False -> {
      let assert Ok(first_chunk) =
        bit_array.slice(encoded_headers, 0, max_frame_size)
      let assert Ok(remaining) =
        bit_array.slice(
          encoded_headers,
          max_frame_size,
          header_size - max_frame_size,
        )
      let header_frame =
        Header(
          data: Continued(first_chunk),
          end_stream: end_stream,
          identifier: stream_identifier,
          priority: None,
        )
      use _nil <- result.try(
        transport.send(
          conn.transport,
          conn.socket,
          bytes_tree.from_bit_array(frame.encode(header_frame)),
        )
        |> result.map_error(fn(_) { "Failed to send HTTP/2 headers" }),
      )
      use _nil <- result.try(send_continuations(
        conn,
        remaining,
        stream_identifier,
        max_frame_size,
      ))
      Ok(new_context)
    }
  }
}

fn send_continuations(
  conn: Connection,
  data: BitArray,
  identifier: StreamIdentifier(Frame),
  max_frame_size: Int,
) -> Result(Nil, String) {
  let size = bit_array.byte_size(data)
  case size <= max_frame_size {
    True -> {
      let cont =
        frame.Continuation(data: Complete(data), identifier: identifier)
      transport.send(
        conn.transport,
        conn.socket,
        bytes_tree.from_bit_array(frame.encode(cont)),
      )
      |> result.map_error(fn(_) { "Failed to send CONTINUATION frame" })
    }
    False -> {
      let assert Ok(chunk) = bit_array.slice(data, 0, max_frame_size)
      let assert Ok(rest) =
        bit_array.slice(data, max_frame_size, size - max_frame_size)
      let cont =
        frame.Continuation(data: Continued(chunk), identifier: identifier)
      use _nil <- result.try(
        transport.send(
          conn.transport,
          conn.socket,
          bytes_tree.from_bit_array(frame.encode(cont)),
        )
        |> result.map_error(fn(_) { "Failed to send CONTINUATION frame" }),
      )
      send_continuations(conn, rest, identifier, max_frame_size)
    }
  }
}

pub fn send_data(
  conn: Connection,
  data: BitArray,
  stream_identifier: StreamIdentifier(Frame),
  end_stream: Bool,
  max_frame_size: Int,
) -> Result(Nil, String) {
  let size = bit_array.byte_size(data)
  case size <= max_frame_size {
    True -> {
      let data_frame =
        Data(data: data, end_stream: end_stream, identifier: stream_identifier)
      transport.send(
        conn.transport,
        conn.socket,
        bytes_tree.from_bit_array(frame.encode(data_frame)),
      )
      |> result.map_error(fn(err) {
        logging.log(
          logging.Debug,
          "Failed to send HTTP/2 data: " <> socket.reason_to_string(err),
        )
        "Failed to send HTTP/2 data"
      })
    }
    False -> {
      let chunk = bit_array.slice(data, 0, max_frame_size)
      let rest = bit_array.slice(data, max_frame_size, size - max_frame_size)
      case chunk, rest {
        Ok(chunk_data), Ok(rest_data) -> {
          let chunk_frame =
            Data(
              data: chunk_data,
              end_stream: False,
              identifier: stream_identifier,
            )
          use _nil <- result.try(
            transport.send(
              conn.transport,
              conn.socket,
              bytes_tree.from_bit_array(frame.encode(chunk_frame)),
            )
            |> result.map_error(fn(err) {
              logging.log(
                logging.Debug,
                "Failed to send HTTP/2 data: " <> socket.reason_to_string(err),
              )
              "Failed to send HTTP/2 data"
            }),
          )
          send_data(
            conn,
            rest_data,
            stream_identifier,
            end_stream,
            max_frame_size,
          )
        }
        _, _ -> Error("Failed to slice HTTP/2 data frame")
      }
    }
  }
}

pub fn send_frame(
  frame_to_send: Frame,
  socket: Socket,
  transport: Transport,
) -> Result(Nil, SocketReason) {
  let data = frame.encode(frame_to_send)

  transport.send(transport, socket, bytes_tree.from_bit_array(data))
}

pub fn send_bytes_tree(
  resp: Response(BytesTree),
  conn: Connection,
  context: HpackContext,
  id: StreamIdentifier(Frame),
  settings: Http2Settings,
) -> Result(HpackContext, String) {
  let resp =
    resp
    |> http.add_default_headers(False)

  let headers = [#(":status", int.to_string(resp.status)), ..resp.headers]

  case bytes_tree.byte_size(resp.body) {
    0 -> send_headers(context, conn, headers, True, id, settings.max_frame_size)
    _ -> {
      send_headers(context, conn, headers, False, id, settings.max_frame_size)
      |> result.try(fn(context) {
        send_data(
          conn,
          bytes_tree.to_bit_array(resp.body),
          id,
          True,
          settings.max_frame_size,
        )
        |> result.replace(context)
      })
    }
  }
}

pub type HpackContext

@external(erlang, "hpack", "new_context")
pub fn hpack_new_context(size: Int) -> HpackContext

@external(erlang, "mist_ffi", "hpack_new_max_table_size")
pub fn hpack_max_table_size(context: HpackContext, size: Int) -> HpackContext

pub type HpackError {
  Compression
  BadHeaderPacket(BitArray)
}

@external(erlang, "mist_ffi", "hpack_decode")
pub fn hpack_decode(
  context: HpackContext,
  bin: BitArray,
) -> Result(#(List(#(String, String)), HpackContext), HpackError)

@external(erlang, "mist_ffi", "hpack_encode")
pub fn hpack_encode(
  context: HpackContext,
  headers: List(#(String, String)),
) -> Result(#(BitArray, HpackContext), error)
