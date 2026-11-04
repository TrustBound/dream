import gleam/option.{None}
import mist/internal/http2/frame.{Complete, Data, Header, stream_identifier}

pub fn it_should_encode_data_frame_test() {
  assert frame.encode(
      Data(identifier: stream_identifier(123), end_stream: False, data: <<
        1, 2, 3,
      >>),
    )
    == <<0, 0, 3, 0, 0, 0, 0, 0, 123, 1, 2, 3>>
}

pub fn it_should_encode_headers_frame_test() {
  assert frame.encode(Header(
      identifier: stream_identifier(123),
      end_stream: False,
      data: Complete(<<1, 2, 3>>),
      priority: None,
    ))
    == <<0, 0, 3, 1, 4, 0, 0, 0, 123, 1, 2, 3>>
}

pub fn it_should_encode_data_frame_with_end_of_stream_test() {
  assert frame.encode(
      Data(identifier: stream_identifier(123), end_stream: True, data: <<
        1, 2, 3,
      >>),
    )
    == <<0, 0, 3, 0, 1, 0, 0, 0, 123, 1, 2, 3>>
}

pub fn it_should_encode_headers_frame_with_end_of_stream_test() {
  assert frame.encode(Header(
      identifier: stream_identifier(123),
      end_stream: True,
      data: Complete(<<1, 2, 3>>),
      priority: None,
    ))
    == <<0, 0, 3, 1, 5, 0, 0, 0, 123, 1, 2, 3>>
}

pub fn it_should_return_error_when_incomplete_test() {
  let data = <<0, 0, 0, 4>>
  assert frame.decode(data) == Error(frame.ProtocolError)
}

pub fn it_should_decode_data_frame_test() {
  let data = <<0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 2, 3>>
  assert frame.decode(data)
    == Ok(
      #(
        frame.Data(
          identifier: stream_identifier(1),
          data: <<>>,
          end_stream: False,
        ),
        <<1, 2, 3>>,
      ),
    )
}

pub fn it_should_decode_full_header_message_test() {
  let msg = <<
    0, 0, 38, 1, 37, 0, 0, 0, 13, 0, 0, 0, 11, 15, 130, 132, 135, 65, 138, 160,
    228, 29, 19, 157, 9, 184, 17, 50, 215, 83, 3, 42, 47, 42, 144, 122, 138, 170,
    105, 210, 154, 196, 192, 87, 109, 229, 193, 0, 0, 0, 4, 1, 0, 0, 0, 0,
  >>

  let assert Ok(#(frame.Header(data, ..), rest)) = frame.decode(msg)

  assert data
    == frame.Complete(<<
      130, 132, 135, 65, 138, 160, 228, 29, 19, 157, 9, 184, 17, 50, 215, 83, 3,
      42, 47, 42, 144, 122, 138, 170, 105, 210, 154, 196, 192, 87, 109, 229, 193,
    >>)

  assert rest == <<0, 0, 0, 4, 1, 0, 0, 0, 0>>
}

pub fn it_should_encode_ping_test() {
  assert frame.encode(frame.Ping(ack: False, data: <<1, 2, 3, 4, 5, 6, 7, 8>>))
    == <<0, 0, 8, 6, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8>>
}

pub fn it_should_encode_ping_ack_test() {
  assert frame.encode(frame.Ping(ack: True, data: <<1, 2, 3, 4, 5, 6, 7, 8>>))
    == <<0, 0, 8, 6, 1, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8>>
}

pub fn it_should_decode_ping_test() {
  let data = <<0, 0, 8, 6, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8>>
  assert frame.decode(data)
    == Ok(#(frame.Ping(ack: False, data: <<1, 2, 3, 4, 5, 6, 7, 8>>), <<>>))
}

pub fn it_should_decode_ping_ack_test() {
  let data = <<0, 0, 8, 6, 1, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8>>
  assert frame.decode(data)
    == Ok(#(frame.Ping(ack: True, data: <<1, 2, 3, 4, 5, 6, 7, 8>>), <<>>))
}

pub fn it_should_reject_ping_with_wrong_length_test() {
  let data = <<0, 0, 4, 6, 0, 0, 0, 0, 0, 1, 2, 3, 4>>
  assert frame.decode(data) == Error(frame.FrameSizeError)
}

pub fn it_should_encode_termination_test() {
  assert frame.encode(frame.Termination(
      error: frame.Cancel,
      identifier: stream_identifier(1),
    ))
    == <<0, 0, 4, 3, 0, 0, 0, 0, 1, 0, 0, 0, 8>>
}

pub fn it_should_decode_termination_test() {
  let data = <<0, 0, 4, 3, 0, 0, 0, 0, 1, 0, 0, 0, 8>>
  assert frame.decode(data)
    == Ok(
      #(
        frame.Termination(error: frame.Cancel, identifier: stream_identifier(1)),
        <<>>,
      ),
    )
}

pub fn it_should_encode_goaway_test() {
  assert frame.encode(frame.GoAway(
      data: <<>>,
      error: frame.NoError,
      last_stream_id: stream_identifier(5),
    ))
    == <<0, 0, 8, 7, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0>>
}

pub fn it_should_decode_goaway_test() {
  let data = <<0, 0, 8, 7, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0>>
  assert frame.decode(data)
    == Ok(
      #(
        frame.GoAway(
          data: <<>>,
          error: frame.NoError,
          last_stream_id: stream_identifier(5),
        ),
        <<>>,
      ),
    )
}

pub fn it_should_encode_goaway_with_debug_data_test() {
  assert frame.encode(frame.GoAway(
      data: <<222, 173>>,
      error: frame.InternalError,
      last_stream_id: stream_identifier(3),
    ))
    == <<0, 0, 10, 7, 0, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 2, 222, 173>>
}

pub fn it_should_decode_goaway_with_debug_data_test() {
  let data = <<0, 0, 10, 7, 0, 0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 2, 222, 173>>
  assert frame.decode(data)
    == Ok(
      #(
        frame.GoAway(
          data: <<222, 173>>,
          error: frame.InternalError,
          last_stream_id: stream_identifier(3),
        ),
        <<>>,
      ),
    )
}

pub fn it_should_encode_window_update_test() {
  assert frame.encode(frame.WindowUpdate(
      amount: 1000,
      identifier: stream_identifier(1),
    ))
    == <<0, 0, 4, 8, 0, 0, 0, 0, 1, 0, 0, 3, 232>>
}

pub fn it_should_decode_window_update_test() {
  let data = <<0, 0, 4, 8, 0, 0, 0, 0, 1, 0, 0, 3, 232>>
  assert frame.decode(data)
    == Ok(
      #(
        frame.WindowUpdate(amount: 1000, identifier: stream_identifier(1)),
        <<>>,
      ),
    )
}

pub fn it_should_reject_window_update_with_zero_increment_test() {
  let data = <<0, 0, 4, 8, 0, 0, 0, 0, 1, 0, 0, 0, 0>>
  assert frame.decode(data) == Error(frame.ProtocolError)
}

pub fn it_should_encode_settings_test() {
  assert frame.encode(
      frame.Settings(ack: False, settings: [frame.MaxFrameSize(32_768)]),
    )
    == <<0, 0, 6, 4, 0, 0, 0, 0, 0, 0, 5, 0, 0, 128, 0>>
}

pub fn it_should_decode_settings_test() {
  let data = <<0, 0, 6, 4, 0, 0, 0, 0, 0, 0, 5, 0, 0, 128, 0>>
  assert frame.decode(data)
    == Ok(
      #(
        frame.Settings(ack: False, settings: [frame.MaxFrameSize(32_768)]),
        <<>>,
      ),
    )
}

pub fn it_should_encode_settings_ack_test() {
  assert frame.encode(frame.settings_ack()) == <<0, 0, 0, 4, 1, 0, 0, 0, 0>>
}

pub fn it_should_decode_settings_ack_test() {
  let data = <<0, 0, 0, 4, 1, 0, 0, 0, 0>>
  assert frame.decode(data)
    == Ok(#(frame.Settings(ack: True, settings: []), <<>>))
}

pub fn it_should_reject_settings_with_wrong_length_test() {
  let data = <<0, 0, 5, 4, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5>>
  assert frame.decode(data) == Error(frame.FrameSizeError)
}

pub fn it_should_encode_priority_test() {
  assert frame.encode(frame.Priority(
      exclusive: True,
      identifier: stream_identifier(3),
      stream_dependency: stream_identifier(1),
      weight: 16,
    ))
    == <<0, 0, 5, 2, 0, 0, 0, 0, 3, 128, 0, 0, 1, 16>>
}

pub fn it_should_decode_priority_test() {
  let data = <<0, 0, 5, 2, 0, 0, 0, 0, 3, 128, 0, 0, 1, 16>>
  assert frame.decode(data)
    == Ok(
      #(
        frame.Priority(
          exclusive: True,
          identifier: stream_identifier(3),
          stream_dependency: stream_identifier(1),
          weight: 16,
        ),
        <<>>,
      ),
    )
}

pub fn it_should_roundtrip_ping_test() {
  let f = frame.Ping(ack: False, data: <<10, 20, 30, 40, 50, 60, 70, 80>>)
  assert frame.decode(frame.encode(f)) == Ok(#(f, <<>>))
}

pub fn it_should_roundtrip_goaway_test() {
  let f =
    frame.GoAway(
      data: <<>>,
      error: frame.NoError,
      last_stream_id: stream_identifier(7),
    )
  assert frame.decode(frame.encode(f)) == Ok(#(f, <<>>))
}

pub fn it_should_roundtrip_goaway_with_debug_data_test() {
  let f =
    frame.GoAway(
      data: <<104, 101, 108, 108, 111>>,
      error: frame.ProtocolError,
      last_stream_id: stream_identifier(11),
    )
  assert frame.decode(frame.encode(f)) == Ok(#(f, <<>>))
}

pub fn it_should_roundtrip_termination_test() {
  let f =
    frame.Termination(
      error: frame.StreamClosed,
      identifier: stream_identifier(5),
    )
  assert frame.decode(frame.encode(f)) == Ok(#(f, <<>>))
}

pub fn it_should_roundtrip_window_update_test() {
  let f = frame.WindowUpdate(amount: 65_535, identifier: stream_identifier(1))
  assert frame.decode(frame.encode(f)) == Ok(#(f, <<>>))
}

pub fn it_should_roundtrip_settings_test() {
  let f = frame.Settings(ack: False, settings: [frame.MaxFrameSize(32_768)])
  assert frame.decode(frame.encode(f)) == Ok(#(f, <<>>))
}

pub fn it_should_roundtrip_priority_test() {
  let f =
    frame.Priority(
      exclusive: False,
      identifier: stream_identifier(5),
      stream_dependency: stream_identifier(3),
      weight: 200,
    )
  assert frame.decode(frame.encode(f)) == Ok(#(f, <<>>))
}

pub fn it_should_roundtrip_data_frame_test() {
  let f =
    Data(identifier: stream_identifier(1), end_stream: True, data: <<
      72,
      101,
      108,
      108,
      111,
    >>)
  assert frame.decode(frame.encode(f)) == Ok(#(f, <<>>))
}

pub fn it_should_roundtrip_headers_frame_test() {
  let f =
    Header(
      identifier: stream_identifier(1),
      end_stream: False,
      data: Complete(<<130, 132, 135>>),
      priority: None,
    )
  assert frame.decode(frame.encode(f)) == Ok(#(f, <<>>))
}

pub fn it_should_decode_unknown_frame_type_test() {
  let input = <<0, 0, 4, 255, 0, 0, 0, 0, 0, 1, 2, 3, 4>>
  let assert Ok(#(frame.Unknown(255), <<>>)) = frame.decode(input)
}
