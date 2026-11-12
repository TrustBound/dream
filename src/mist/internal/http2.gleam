import gleam/bytes_tree.{type BytesTree}
import gleam/http.{type Header} as _ghttp
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
  Continuation, Continued, Data, Header,
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
  headers: List(Header),
  end_stream: Bool,
  stream_identifier: StreamIdentifier(Frame),
  max_frame_size: Int,
) -> Result(HpackContext, String) {
  encode_headers(
    context,
    headers,
    end_stream,
    stream_identifier,
    max_frame_size,
  )
  |> result.try(fn(pair) {
    let #(encoded, new_context) = pair
    send_encoded(conn, encoded)
    |> result.replace(new_context)
  })
}

pub fn send_encoded(conn: Connection, encoded: BitArray) -> Result(Nil, String) {
  case encoded {
    <<>> -> Ok(Nil)
    _ ->
      transport.send(
        conn.transport,
        conn.socket,
        bytes_tree.from_bit_array(encoded),
      )
      |> result.replace_error("Failed to send HTTP/2 headers")
  }
}

pub fn encode_headers(
  context: HpackContext,
  headers: List(Header),
  end_stream: Bool,
  stream_identifier: StreamIdentifier(Frame),
  max_frame_size: Int,
) -> Result(#(BitArray, HpackContext), String) {
  hpack_encode(context, headers)
  |> result.map(fn(pair) {
    let #(headers, new_context) = pair
    let #(data, continuation) = case headers {
      <<data:bytes-size(max_frame_size), rest:bits>> if rest != <<>> -> #(
        Continued(data),
        encode_continuation(rest, stream_identifier, max_frame_size),
      )
      _ -> #(Complete(headers), <<>>)
    }
    let header_frame =
      Header(
        data: data,
        end_stream: end_stream,
        identifier: stream_identifier,
        priority: None,
      )
    #(<<frame.encode(header_frame):bits, continuation:bits>>, new_context)
  })
}

fn encode_continuation(
  data: BitArray,
  stream_identifier: StreamIdentifier(Frame),
  max_frame_size: Int,
) -> BitArray {
  case data {
    <<data:bytes-size(max_frame_size), rest:bits>> if rest != <<>> -> {
      let continuation =
        Continuation(data: Continued(data), identifier: stream_identifier)
      <<
        frame.encode(continuation):bits,
        encode_continuation(rest, stream_identifier, max_frame_size):bits,
      >>
    }
    _ ->
      frame.encode(Continuation(
        data: Complete(data),
        identifier: stream_identifier,
      ))
  }
}

pub fn send_body(
  conn: Connection,
  before: BitArray,
  data: BitArray,
  stream_identifier: StreamIdentifier(Frame),
  end_stream: Bool,
  max_frame_size: Int,
) -> Result(Nil, String) {
  let encoded =
    bytes_tree.from_bit_array(before)
    |> encode_body(data, stream_identifier, end_stream, max_frame_size)

  transport.send(conn.transport, conn.socket, encoded)
  |> result.map_error(fn(err) {
    logging.log(
      logging.Debug,
      "failed to send :(  " <> socket.reason_to_string(err),
    )
    "Failed to send HTTP/2 data"
  })
}

fn encode_body(
  encoded: BytesTree,
  data: BitArray,
  stream_identifier: StreamIdentifier(Frame),
  end_stream: Bool,
  max_frame_size: Int,
) -> BytesTree {
  case data {
    <<data:bytes-size(max_frame_size), rest:bits>> if rest != <<>> -> {
      Data(data: data, end_stream: False, identifier: stream_identifier)
      |> frame.encode
      |> bytes_tree.append(encoded, _)
      |> encode_body(rest, stream_identifier, end_stream, max_frame_size)
    }
    _ ->
      Data(data: data, end_stream: end_stream, identifier: stream_identifier)
      |> frame.encode
      |> bytes_tree.append(encoded, _)
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

pub fn encode_response(
  resp: Response(BytesTree),
  context: HpackContext,
  id: StreamIdentifier(Frame),
  max_frame_size: Int,
) -> Result(#(BitArray, HpackContext), String) {
  let resp =
    resp
    |> http.add_default_headers(False)

  let headers = [#(":status", int.to_string(resp.status)), ..resp.headers]

  let end_stream = bytes_tree.byte_size(resp.body) == 0

  encode_headers(context, headers, end_stream, id, max_frame_size)
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
) -> Result(#(List(Header), HpackContext), HpackError)

@external(erlang, "mist_ffi", "hpack_encode")
pub fn hpack_encode(
  context: HpackContext,
  headers: List(Header),
) -> Result(#(BitArray, HpackContext), error)
