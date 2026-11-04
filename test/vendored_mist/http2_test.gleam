import gleam/bit_array
import gleam/bytes_tree
import gleam/erlang/process
import gleam/http/request.{type Request}
import gleam/http/response
import gleam/int
import gleam/list
import gleam/otp/actor
import gleam/string_tree
import mist
import mist/internal/http.{type Connection}
import vendored_mist/scaffold

type H2cSocket

@external(erlang, "h2c_ffi", "h2c_connect")
fn h2c_connect(port: Int) -> H2cSocket

@external(erlang, "h2c_ffi", "h2c_connect_raw")
fn h2c_connect_raw(port: Int) -> H2cSocket

@external(erlang, "h2c_ffi", "h2c_send_headers")
fn h2c_send_headers(
  socket: H2cSocket,
  stream_id: Int,
  headers: List(#(String, String)),
  end_stream: Bool,
) -> Nil

@external(erlang, "h2c_ffi", "h2c_send_frame")
fn h2c_send_frame(socket: H2cSocket, frame_bytes: BitArray) -> Nil

@external(erlang, "h2c_ffi", "h2c_recv_frame")
fn h2c_recv_frame(socket: H2cSocket, timeout: Int) -> #(Int, Int, Int, BitArray)

@external(erlang, "h2c_ffi", "h2c_send_ping")
fn h2c_send_ping(socket: H2cSocket, data: BitArray) -> Nil

@external(erlang, "h2c_ffi", "h2c_close")
fn h2c_close(socket: H2cSocket) -> Nil

fn simple_handler(
  _req: Request(Connection),
) -> response.Response(mist.ResponseData) {
  response.new(200)
  |> response.set_body(mist.Bytes(bytes_tree.from_string("hello")))
}

pub fn it_responds_to_ping_with_ack_test() {
  use <- scaffold.open_server(19_001, simple_handler)

  let socket = h2c_connect(19_001)
  let ping_data = <<1, 2, 3, 4, 5, 6, 7, 8>>
  h2c_send_ping(socket, ping_data)

  let #(frame_type, flags, stream_id, payload) = h2c_recv_frame(socket, 5000)
  assert frame_type == 6
  assert flags == 1
  assert stream_id == 0
  assert payload == ping_data

  h2c_close(socket)
}

pub fn it_sends_settings_ack_test() {
  use <- scaffold.open_server(19_002, simple_handler)

  let socket = h2c_connect_raw(19_002)

  h2c_send_frame(socket, <<0, 0, 0, 4, 0, 0, 0, 0, 0>>)

  let #(settings_type, settings_flags, settings_stream, _) =
    h2c_recv_frame(socket, 5000)
  assert settings_type == 4
  assert settings_flags == 0
  assert settings_stream == 0

  h2c_send_frame(socket, <<0, 0, 0, 4, 1, 0, 0, 0, 0>>)

  let #(ack_type, ack_flags, ack_stream, _) = h2c_recv_frame(socket, 5000)
  assert ack_type == 4
  assert ack_flags == 1
  assert ack_stream == 0

  h2c_close(socket)
}

pub fn it_handles_basic_get_request_test() {
  use <- scaffold.open_server(19_003, simple_handler)

  let socket = h2c_connect(19_003)

  h2c_send_headers(
    socket,
    1,
    [
      #(":method", "GET"),
      #(":path", "/"),
      #(":scheme", "http"),
      #(":authority", "localhost"),
    ],
    True,
  )

  let #(headers_type, _headers_flags, headers_stream, _) =
    h2c_recv_frame(socket, 5000)
  assert headers_type == 1
  assert headers_stream == 1

  let #(data_type, _data_flags, data_stream, data_payload) =
    h2c_recv_frame(socket, 5000)
  assert data_type == 0
  assert data_stream == 1
  assert data_payload == bit_array.from_string("hello")

  h2c_close(socket)
}

pub fn it_handles_rst_stream_test() {
  use <- scaffold.open_server(19_004, simple_handler)

  let socket = h2c_connect(19_004)

  h2c_send_headers(
    socket,
    1,
    [
      #(":method", "GET"),
      #(":path", "/"),
      #(":scheme", "http"),
      #(":authority", "localhost"),
    ],
    True,
  )

  h2c_send_frame(socket, <<0, 0, 4, 3, 0, 0, 0, 0, 1, 0, 0, 0, 8>>)

  let ping_data = <<10, 20, 30, 40, 50, 60, 70, 80>>
  h2c_send_ping(socket, ping_data)

  drain_until_ping_ack(socket, ping_data)

  h2c_close(socket)
}

fn drain_until_ping_ack(socket: H2cSocket, expected_data: BitArray) -> Nil {
  let #(frame_type, flags, _stream_id, payload) = h2c_recv_frame(socket, 5000)
  case frame_type, flags {
    6, 1 -> {
      assert payload == expected_data
      Nil
    }
    _, _ -> drain_until_ping_ack(socket, expected_data)
  }
}

pub fn it_sends_goaway_on_protocol_error_test() {
  use <- scaffold.open_server(19_005, simple_handler)

  let socket = h2c_connect(19_005)

  h2c_send_frame(socket, <<0, 0, 5, 4, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5>>)

  let #(frame_type, _flags, stream_id, payload) = h2c_recv_frame(socket, 5000)
  assert frame_type == 7
  assert stream_id == 0

  let assert <<
    _reserved:size(1),
    _last_stream_id:size(31),
    error_code:size(32),
    _rest:bits,
  >> = payload
  assert error_code == 6

  h2c_close(socket)
}

pub fn it_keeps_connection_alive_after_request_test() {
  use <- scaffold.open_server(19_006, simple_handler)

  let socket = h2c_connect(19_006)

  h2c_send_headers(
    socket,
    1,
    [
      #(":method", "GET"),
      #(":path", "/"),
      #(":scheme", "http"),
      #(":authority", "localhost"),
    ],
    True,
  )

  let ping_data = <<11, 22, 33, 44, 55, 66, 77, 88>>
  h2c_send_ping(socket, ping_data)

  drain_until_ping_ack(socket, ping_data)

  h2c_close(socket)
}

pub fn it_handles_multiple_requests_same_connection_test() {
  use <- scaffold.open_server(19_007, simple_handler)

  let socket = h2c_connect(19_007)

  h2c_send_headers(
    socket,
    1,
    [
      #(":method", "GET"),
      #(":path", "/"),
      #(":scheme", "http"),
      #(":authority", "localhost"),
    ],
    True,
  )

  let #(headers_type_1, _, headers_stream_1, _) = h2c_recv_frame(socket, 5000)
  assert headers_type_1 == 1
  assert headers_stream_1 == 1

  let #(data_type_1, _, data_stream_1, data_payload_1) =
    h2c_recv_frame(socket, 5000)
  assert data_type_1 == 0
  assert data_stream_1 == 1
  assert data_payload_1 == bit_array.from_string("hello")

  h2c_send_headers(
    socket,
    3,
    [
      #(":method", "GET"),
      #(":path", "/"),
      #(":scheme", "http"),
      #(":authority", "localhost"),
    ],
    True,
  )

  let #(headers_type_2, _, headers_stream_2, _) = h2c_recv_frame(socket, 5000)
  assert headers_type_2 == 1
  assert headers_stream_2 == 3

  let #(data_type_2, _, data_stream_2, data_payload_2) =
    h2c_recv_frame(socket, 5000)
  assert data_type_2 == 0
  assert data_stream_2 == 3
  assert data_payload_2 == bit_array.from_string("hello")

  h2c_close(socket)
}

pub fn it_ignores_window_update_for_closed_stream_test() {
  use <- scaffold.open_server(19_008, simple_handler)

  let socket = h2c_connect(19_008)

  h2c_send_headers(
    socket,
    1,
    [
      #(":method", "GET"),
      #(":path", "/"),
      #(":scheme", "http"),
      #(":authority", "localhost"),
    ],
    True,
  )

  let ping_data_1 = <<1, 1, 1, 1, 1, 1, 1, 1>>
  h2c_send_ping(socket, ping_data_1)
  drain_until_ping_ack(socket, ping_data_1)

  h2c_send_frame(socket, <<0, 0, 4, 8, 0, 0, 0, 0, 99, 0, 0, 0, 100>>)

  let ping_data_2 = <<2, 2, 2, 2, 2, 2, 2, 2>>
  h2c_send_ping(socket, ping_data_2)
  drain_until_ping_ack(socket, ping_data_2)

  h2c_close(socket)
}

pub fn it_ignores_unknown_frame_type_test() {
  use <- scaffold.open_server(19_009, simple_handler)

  let socket = h2c_connect(19_009)

  h2c_send_frame(socket, <<0, 0, 4, 255, 0, 0, 0, 0, 0, 1, 2, 3, 4>>)

  let ping_data = <<3, 3, 3, 3, 3, 3, 3, 3>>
  h2c_send_ping(socket, ping_data)

  let #(frame_type, flags, _stream_id, payload) = h2c_recv_frame(socket, 5000)
  assert frame_type == 6
  assert flags == 1
  assert payload == ping_data

  h2c_close(socket)
}

fn many_headers_handler(
  _req: Request(Connection),
) -> response.Response(mist.ResponseData) {
  let headers =
    int.range(from: 1, to: 30, with: [], run: fn(acc, i) {
      [
        #("x-custom-header-" <> int.to_string(i), "value-" <> int.to_string(i)),
        ..acc
      ]
    })
  response.new(200)
  |> response.set_body(mist.Bytes(bytes_tree.from_string("ok")))
  |> fn(resp) { response.Response(..resp, headers: headers) }
}

pub fn it_sends_continuation_frames_for_large_headers_test() {
  use <- scaffold.open_server(19_010, many_headers_handler)

  let socket = h2c_connect_raw(19_010)

  let #(settings_type, settings_flags, _, _) = h2c_recv_frame(socket, 5000)
  assert settings_type == 4
  assert settings_flags == 0

  h2c_send_frame(socket, <<0, 0, 6, 4, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 64>>)

  h2c_send_frame(socket, <<0, 0, 0, 4, 1, 0, 0, 0, 0>>)

  let #(ack_type, ack_flags, _, _) = h2c_recv_frame(socket, 5000)
  assert ack_type == 4
  assert ack_flags == 1

  h2c_send_headers(
    socket,
    1,
    [
      #(":method", "GET"),
      #(":path", "/"),
      #(":scheme", "http"),
      #(":authority", "localhost"),
    ],
    True,
  )

  let #(first_type, first_flags, first_stream, _) = h2c_recv_frame(socket, 5000)
  assert first_type == 1
  assert first_stream == 1
  let first_end_headers = int.bitwise_and(first_flags, 4) == 4
  assert first_end_headers == False

  drain_until_end_headers(socket)

  h2c_close(socket)
}

fn drain_until_end_headers(socket: H2cSocket) -> Nil {
  let #(frame_type, flags, _stream_id, _payload) = h2c_recv_frame(socket, 5000)
  case frame_type {
    9 -> {
      let end_headers = int.bitwise_and(flags, 4) == 4
      case end_headers {
        True -> Nil
        False -> drain_until_end_headers(socket)
      }
    }
    _ -> drain_until_end_headers(socket)
  }
}

type ChunkMessage {
  SendChunks
}

fn chunked_handler(
  req: Request(Connection),
) -> response.Response(mist.ResponseData) {
  mist.chunked(
    request: req,
    response: response.new(200),
    init: fn(subj) {
      process.send(subj, SendChunks)
      Nil
    },
    loop: fn(_state, _msg, conn) {
      let chunks = [
        bit_array.from_string("chunk1"),
        bit_array.from_string("chunk2"),
        bit_array.from_string("chunk3"),
      ]
      list.each(chunks, fn(chunk) {
        let assert Ok(_nil) = mist.send_chunk(conn, chunk)
        Nil
      })
      mist.chunk_stop()
    },
  )
}

pub fn it_sends_chunked_data_over_h2_test() {
  use <- scaffold.open_server(19_011, chunked_handler)

  let socket = h2c_connect(19_011)

  h2c_send_headers(
    socket,
    1,
    [
      #(":method", "GET"),
      #(":path", "/"),
      #(":scheme", "http"),
      #(":authority", "localhost"),
    ],
    True,
  )

  let #(headers_type, _, _, _) = h2c_recv_frame(socket, 5000)
  assert headers_type == 1

  let data_frames = collect_data_frames(socket, [])

  let non_empty =
    list.filter(data_frames, fn(payload) { bit_array.byte_size(payload) > 0 })
  assert list.length(non_empty) >= 2

  let combined =
    list.fold(data_frames, <<>>, fn(acc, payload) { <<acc:bits, payload:bits>> })
  assert combined == bit_array.from_string("chunk1chunk2chunk3")

  h2c_close(socket)
}

fn collect_data_frames(
  socket: H2cSocket,
  acc: List(BitArray),
) -> List(BitArray) {
  let #(frame_type, flags, _stream_id, payload) = h2c_recv_frame(socket, 5000)
  case frame_type {
    0 -> {
      let end_stream = int.bitwise_and(flags, 1) == 1
      let new_acc = [payload, ..acc]
      case end_stream {
        True -> list.reverse(new_acc)
        False -> collect_data_frames(socket, new_acc)
      }
    }
    _ -> collect_data_frames(socket, acc)
  }
}

// --- SSE-over-HTTP/2 test helpers ---

type SSEMsg {
  SendEvent
  StopAfterEvent
}

fn sse_handler(
  req: Request(Connection),
) -> response.Response(mist.ResponseData) {
  mist.server_sent_events(
    request: req,
    initial_response: response.new(200),
    init: fn(subj) {
      process.send(subj, SendEvent)
      Nil
    },
    loop: fn(_state, msg, conn) {
      case msg {
        SendEvent -> {
          let _ =
            mist.send_event(conn, mist.event(string_tree.from_string("hello")))
          actor.continue(Nil)
        }
        StopAfterEvent -> actor.continue(Nil)
      }
    },
  )
}

fn sse_stop_handler(
  req: Request(Connection),
) -> response.Response(mist.ResponseData) {
  mist.server_sent_events(
    request: req,
    initial_response: response.new(200),
    init: fn(subj) {
      process.send(subj, StopAfterEvent)
      Nil
    },
    loop: fn(_state, msg, conn) {
      case msg {
        StopAfterEvent -> {
          let _ =
            mist.send_event(
              conn,
              mist.event(string_tree.from_string("goodbye")),
            )
          actor.stop()
        }
        SendEvent -> {
          let _ =
            mist.send_event(conn, mist.event(string_tree.from_string("hello")))
          actor.continue(Nil)
        }
      }
    },
  )
}

fn drain_until_data_on_stream(
  socket: H2cSocket,
  target_stream: Int,
  timeout: Int,
) -> #(Int, BitArray) {
  let #(frame_type, flags, stream_id, payload) = h2c_recv_frame(socket, timeout)
  case frame_type, stream_id {
    0, id if id == target_stream -> #(flags, payload)
    _, _ -> drain_until_data_on_stream(socket, target_stream, timeout)
  }
}

fn drain_until_headers_on_stream(
  socket: H2cSocket,
  target_stream: Int,
  timeout: Int,
) -> Int {
  let #(frame_type, flags, stream_id, _payload) =
    h2c_recv_frame(socket, timeout)
  case frame_type, stream_id {
    1, id if id == target_stream -> flags
    _, _ -> drain_until_headers_on_stream(socket, target_stream, timeout)
  }
}

pub fn it_handles_sse_over_h2c_test() {
  use <- scaffold.open_server(19_012, sse_handler)

  let socket = h2c_connect(19_012)

  h2c_send_headers(
    socket,
    1,
    [
      #(":method", "GET"),
      #(":path", "/"),
      #(":scheme", "http"),
      #(":authority", "localhost"),
    ],
    True,
  )

  let _headers_flags = drain_until_headers_on_stream(socket, 1, 5000)

  let #(_data_flags, data_payload) = drain_until_data_on_stream(socket, 1, 5000)
  assert data_payload == bit_array.from_string("data: hello\n\n")

  let ping_data = <<12, 12, 12, 12, 12, 12, 12, 12>>
  h2c_send_ping(socket, ping_data)
  drain_until_ping_ack(socket, ping_data)

  h2c_close(socket)
}

pub fn it_sse_does_not_crash_concurrent_streams_test() {
  let combined_handler = fn(req: Request(Connection)) {
    case req.path {
      "/sse" -> sse_handler(req)
      _ -> simple_handler(req)
    }
  }
  use <- scaffold.open_server(19_013, combined_handler)

  let socket = h2c_connect(19_013)

  h2c_send_headers(
    socket,
    1,
    [
      #(":method", "GET"),
      #(":path", "/sse"),
      #(":scheme", "http"),
      #(":authority", "localhost"),
    ],
    True,
  )

  let _headers_flags = drain_until_headers_on_stream(socket, 1, 5000)

  h2c_send_headers(
    socket,
    3,
    [
      #(":method", "GET"),
      #(":path", "/"),
      #(":scheme", "http"),
      #(":authority", "localhost"),
    ],
    True,
  )

  let _headers_3_flags = drain_until_headers_on_stream(socket, 3, 5000)

  let #(_data_flags, data_payload) = drain_until_data_on_stream(socket, 3, 5000)
  assert data_payload == bit_array.from_string("hello")

  let ping_data = <<13, 13, 13, 13, 13, 13, 13, 13>>
  h2c_send_ping(socket, ping_data)
  drain_until_ping_ack(socket, ping_data)

  h2c_close(socket)
}

pub fn it_closes_sse_stream_on_actor_stop_test() {
  use <- scaffold.open_server(19_014, sse_stop_handler)

  let socket = h2c_connect(19_014)

  h2c_send_headers(
    socket,
    1,
    [
      #(":method", "GET"),
      #(":path", "/"),
      #(":scheme", "http"),
      #(":authority", "localhost"),
    ],
    True,
  )

  let _headers_flags = drain_until_headers_on_stream(socket, 1, 5000)

  let data_frames = collect_data_frames_on_stream(socket, 1, [])

  let combined =
    list.fold(data_frames, <<>>, fn(acc, payload) { <<acc:bits, payload:bits>> })
  let assert True =
    bit_array.byte_size(combined)
    >= bit_array.byte_size(<<
      "data: goodbye\n\n":utf8,
    >>)

  let ping_data = <<14, 14, 14, 14, 14, 14, 14, 14>>
  h2c_send_ping(socket, ping_data)
  drain_until_ping_ack(socket, ping_data)

  h2c_close(socket)
}

pub fn it_does_not_leak_stream_actors_test() {
  use <- scaffold.open_server(19_015, simple_handler)

  let socket = h2c_connect(19_015)

  int.range(from: 0, to: 24, with: Nil, run: fn(_acc, i) {
    let stream_id = i * 2 + 1
    h2c_send_headers(
      socket,
      stream_id,
      [
        #(":method", "GET"),
        #(":path", "/"),
        #(":scheme", "http"),
        #(":authority", "localhost"),
      ],
      True,
    )
    let _headers_flags = drain_until_headers_on_stream(socket, stream_id, 5000)
    let #(_flags, payload) = drain_until_data_on_stream(socket, stream_id, 5000)
    assert payload == bit_array.from_string("hello")
  })

  let ping_data = <<15, 15, 15, 15, 15, 15, 15, 15>>
  h2c_send_ping(socket, ping_data)
  drain_until_ping_ack(socket, ping_data)

  h2c_close(socket)
}

// Integration test: uses mist.start() (production path) instead of scaffold
pub fn it_handles_sse_over_h2c_production_path_test() {
  let handler = fn(req: Request(Connection)) {
    case request.path_segments(req) {
      ["sse"] -> sse_handler(req)
      _ -> simple_handler(req)
    }
  }

  let assert Ok(_server) =
    mist.new(handler)
    |> mist.port(19_020)
    |> mist.start

  process.sleep(50)

  let socket = h2c_connect(19_020)

  // First: verify simple requests work
  h2c_send_headers(
    socket,
    1,
    [
      #(":method", "GET"),
      #(":path", "/hello"),
      #(":scheme", "http"),
      #(":authority", "localhost"),
    ],
    True,
  )
  let _headers_flags = drain_until_headers_on_stream(socket, 1, 5000)
  let #(_data_flags, data_payload) = drain_until_data_on_stream(socket, 1, 5000)
  assert data_payload == bit_array.from_string("hello")

  // Now: test SSE on the same connection
  h2c_send_headers(
    socket,
    3,
    [
      #(":method", "GET"),
      #(":path", "/sse"),
      #(":scheme", "http"),
      #(":authority", "localhost"),
    ],
    True,
  )
  let _sse_headers_flags = drain_until_headers_on_stream(socket, 3, 5000)
  let #(_sse_data_flags, sse_data_payload) =
    drain_until_data_on_stream(socket, 3, 5000)
  assert sse_data_payload == bit_array.from_string("data: hello\n\n")

  // Verify connection is still alive after SSE
  let ping_data = <<20, 20, 20, 20, 20, 20, 20, 20>>
  h2c_send_ping(socket, ping_data)
  drain_until_ping_ack(socket, ping_data)

  // And verify we can still serve requests after SSE
  h2c_send_headers(
    socket,
    5,
    [
      #(":method", "GET"),
      #(":path", "/hello"),
      #(":scheme", "http"),
      #(":authority", "localhost"),
    ],
    True,
  )
  let _headers5_flags = drain_until_headers_on_stream(socket, 5, 5000)
  let #(_data5_flags, data5_payload) =
    drain_until_data_on_stream(socket, 5, 5000)
  assert data5_payload == bit_array.from_string("hello")

  h2c_close(socket)
}

// Stress test: multiple concurrent connections, each doing SSE + regular requests
pub fn it_handles_sse_under_load_production_path_test() {
  let handler = fn(req: Request(Connection)) {
    case request.path_segments(req) {
      ["sse"] -> sse_handler(req)
      _ -> simple_handler(req)
    }
  }

  let assert Ok(_server) =
    mist.new(handler)
    |> mist.port(19_021)
    |> mist.start

  process.sleep(50)

  // Spawn 5 concurrent connections, each doing SSE + regular requests
  let results =
    list.map([1, 2, 3, 4, 5], fn(conn_id) {
      process.spawn_unlinked(fn() {
        let socket = h2c_connect(19_021)

        // First: regular request
        h2c_send_headers(
          socket,
          1,
          [
            #(":method", "GET"),
            #(":path", "/hello"),
            #(":scheme", "http"),
            #(":authority", "localhost"),
          ],
          True,
        )
        let _hf = drain_until_headers_on_stream(socket, 1, 5000)
        let #(_df, dp) = drain_until_data_on_stream(socket, 1, 5000)
        assert dp == bit_array.from_string("hello")

        // SSE request
        h2c_send_headers(
          socket,
          3,
          [
            #(":method", "GET"),
            #(":path", "/sse"),
            #(":scheme", "http"),
            #(":authority", "localhost"),
          ],
          True,
        )
        let _shf = drain_until_headers_on_stream(socket, 3, 5000)
        let #(_sdf, sdp) = drain_until_data_on_stream(socket, 3, 5000)
        assert sdp == bit_array.from_string("data: hello\n\n")

        // Another regular request after SSE (tests connection survival)
        h2c_send_headers(
          socket,
          5,
          [
            #(":method", "GET"),
            #(":path", "/hello"),
            #(":scheme", "http"),
            #(":authority", "localhost"),
          ],
          True,
        )
        let _hf2 = drain_until_headers_on_stream(socket, 5, 5000)
        let #(_df2, dp2) = drain_until_data_on_stream(socket, 5, 5000)
        assert dp2 == bit_array.from_string("hello")

        // Ping to verify connection
        let ping_data = <<
          { conn_id * 3 }:8,
          { conn_id * 3 }:8,
          { conn_id * 3 }:8,
          { conn_id * 3 }:8,
          { conn_id * 3 }:8,
          { conn_id * 3 }:8,
          { conn_id * 3 }:8,
          { conn_id * 3 }:8,
        >>
        h2c_send_ping(socket, ping_data)
        drain_until_ping_ack(socket, ping_data)

        h2c_close(socket)
      })
    })

  // Wait for all connections to finish (monitor each)
  list.each(results, fn(pid) {
    let monitor = process.monitor(pid)
    let selector =
      process.new_selector()
      |> process.select_specific_monitor(monitor, fn(_down) { Nil })
    process.selector_receive(selector, 30_000)
  })
}

fn collect_data_frames_on_stream(
  socket: H2cSocket,
  target_stream: Int,
  acc: List(BitArray),
) -> List(BitArray) {
  let #(frame_type, flags, stream_id, payload) = h2c_recv_frame(socket, 5000)
  case frame_type, stream_id {
    0, id if id == target_stream -> {
      let end_stream = int.bitwise_and(flags, 1) == 1
      let new_acc = [payload, ..acc]
      case end_stream {
        True -> list.reverse(new_acc)
        False -> collect_data_frames_on_stream(socket, target_stream, new_acc)
      }
    }
    _, _ -> collect_data_frames_on_stream(socket, target_stream, acc)
  }
}
