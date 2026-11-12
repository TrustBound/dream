import gleam/bit_array
import gleam/bytes_tree
import gleam/erlang/process
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/list
import gleam/option.{Some}
import gleam/otp/actor
import gleam/string
import gleam/string_tree
import mist
import mist/internal/http2/frame
import vendored_mist/scaffold.{bitstring_response_should_equal}

pub fn it_applies_pseudo_headers_test() {
  let headers = [
    #(":method", "POST"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/some/path?x=1"),
  ]

  use <- scaffold.open_server(8888, scaffold.uri_echo_handler)

  let actual = scaffold.http2_request(headers)

  let expected =
    response.new(200)
    |> response.prepend_header("content-length", "42")
    |> response.set_body(
      bytes_tree.from_bit_array(<<
        "POST http://example.com:8080/some/path?x=1":utf8,
      >>),
    )

  bitstring_response_should_equal(actual, expected)
}

pub fn it_rejects_requests_without_host_test() {
  let headers = [#(":method", "GET"), #(":scheme", "http"), #(":path", "/")]

  use <- scaffold.open_server(8888, scaffold.uri_echo_handler)

  let actual = scaffold.http2_request(headers)

  let expected =
    response.new(400)
    |> response.prepend_header("content-length", "0")
    |> response.set_body(bytes_tree.from_bit_array(<<>>))

  bitstring_response_should_equal(actual, expected)
}

pub fn it_ignores_unknown_frames_test() {
  let headers = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]

  use <- scaffold.open_server(8888, scaffold.uri_echo_handler)

  let actual =
    scaffold.http2_request_after(<<0, 0, 1, 255, 0, 0, 0, 0, 1, 0>>, headers)

  let expected =
    response.new(200)
    |> response.prepend_header("content-length", "28")
    |> response.set_body(
      bytes_tree.from_bit_array(<<"GET http://example.com:8080/":utf8>>),
    )

  bitstring_response_should_equal(actual, expected)
}

pub fn it_responds_after_reading_the_body_test() {
  let headers = [
    #(":method", "POST"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
    #("content-length", "10"),
  ]

  use <- scaffold.open_server(8888, scaffold.default_handler)

  let actual = scaffold.http2_request_with_body(headers, <<"0123456789":utf8>>)

  let expected =
    response.new(200)
    |> response.prepend_header("host", "example.com:8080")
    |> response.prepend_header("content-length", "10")
    |> response.set_body(bytes_tree.from_bit_array(<<"0123456789":utf8>>))

  bitstring_response_should_equal(actual, expected)
}

pub fn it_ignores_window_updates_on_closed_streams_test() {
  let headers = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]

  use <- scaffold.open_server(8888, scaffold.uri_echo_handler)

  let assert [_first, actual] =
    scaffold.http2_requests([
      #(<<>>, headers, <<>>),
      #(<<0, 0, 4, 8, 0, 0, 0, 0, 1, 0, 0, 3, 232>>, headers, <<>>),
    ])

  let expected =
    response.new(200)
    |> response.prepend_header("content-length", "28")
    |> response.set_body(
      bytes_tree.from_bit_array(<<"GET http://example.com:8080/":utf8>>),
    )

  bitstring_response_should_equal(actual, expected)
}

pub fn it_handles_frames_sent_with_the_preface_test() {
  let headers = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]

  use <- scaffold.open_server(8888, scaffold.uri_echo_handler)

  let actual = scaffold.http2_request(headers)

  let expected =
    response.new(200)
    |> response.prepend_header("content-length", "28")
    |> response.set_body(
      bytes_tree.from_bit_array(<<"GET http://example.com:8080/":utf8>>),
    )

  bitstring_response_should_equal(actual, expected)
}

pub fn it_splits_large_bodies_into_frames_test() {
  let headers = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]
  let body = <<string.repeat("a", 60_000):utf8>>

  use <- scaffold.open_server(8888, fn(_req) {
    response.new(200)
    |> response.set_body(mist.Bytes(bytes_tree.from_bit_array(body)))
  })

  let actual = scaffold.http2_request(headers)

  let expected =
    response.new(200)
    |> response.prepend_header("content-length", "60000")
    |> response.set_body(bytes_tree.from_bit_array(body))

  bitstring_response_should_equal(actual, expected)
}

pub fn it_splits_large_headers_into_frames_test() {
  let headers = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]
  let value = string.repeat("a", 20_000)

  use <- scaffold.open_server(8888, fn(_req) {
    response.new(200)
    |> response.set_header("x-large", value)
    |> response.set_body(mist.Bytes(bytes_tree.new()))
  })

  let actual = scaffold.http2_request(headers)

  let expected =
    response.new(200)
    |> response.prepend_header("x-large", value)
    |> response.prepend_header("content-length", "0")
    |> response.set_body(bytes_tree.from_bit_array(<<>>))

  bitstring_response_should_equal(actual, expected)
}

pub fn it_resets_data_on_closed_streams_test() {
  let headers = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]

  use <- scaffold.open_server(8888, scaffold.uri_echo_handler)

  let assert [_first, actual] =
    scaffold.http2_requests([
      #(<<>>, headers, <<>>),
      #(<<0, 0, 1, 0, 0, 0, 0, 0, 1, 97>>, headers, <<>>),
    ])

  let expected =
    response.new(200)
    |> response.prepend_header("content-length", "28")
    |> response.set_body(
      bytes_tree.from_bit_array(<<"GET http://example.com:8080/":utf8>>),
    )

  bitstring_response_should_equal(actual, expected)
}

pub fn it_resets_streams_with_invalid_methods_test() {
  let invalid = [
    #(":method", "BAD METHOD"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]
  let headers = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]

  use <- scaffold.open_server(8888, scaffold.uri_echo_handler)

  let assert [_reset, actual] =
    scaffold.http2_requests([#(<<>>, invalid, <<>>), #(<<>>, headers, <<>>)])

  let expected =
    response.new(200)
    |> response.prepend_header("content-length", "28")
    |> response.set_body(
      bytes_tree.from_bit_array(<<"GET http://example.com:8080/":utf8>>),
    )

  bitstring_response_should_equal(actual, expected)
}

pub fn it_responds_to_ping_test() {
  let headers = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]

  use <- scaffold.open_server(8888, scaffold.uri_echo_handler)

  let actual =
    scaffold.http2_request_after(
      <<0, 0, 8, 6, 0, 0, 0, 0, 0, "pingpong":utf8>>,
      headers,
    )

  let expected =
    response.new(0)
    |> response.set_body(bytes_tree.from_bit_array(<<"pingpong":utf8>>))

  bitstring_response_should_equal(actual, expected)
}

pub fn it_stops_reset_streams_test() {
  let slow = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/slow"),
  ]
  let headers = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]
  let pids = process.new_subject()

  use <- scaffold.open_server(8888, fn(req) {
    case request.path_segments(req) {
      ["slow"] -> {
        process.send(pids, process.self())
        process.sleep_forever()
        scaffold.uri_echo_handler(req)
      }
      _ -> scaffold.uri_echo_handler(req)
    }
  })

  let assert [_ping, actual] =
    scaffold.http2_requests([
      #(<<0, 0, 8, 6, 0, 0, 0, 0, 0, "pingpong":utf8>>, slow, <<>>),
      #(<<0, 0, 4, 3, 0, 0, 0, 0, 1, 0, 0, 0, 8>>, headers, <<>>),
    ])
  let assert Ok(pid) = process.receive(pids, 1000)

  let expected =
    response.new(200)
    |> response.prepend_header("content-length", "28")
    |> response.set_body(
      bytes_tree.from_bit_array(<<"GET http://example.com:8080/":utf8>>),
    )

  bitstring_response_should_equal(actual, expected)
  assert !process.is_alive(pid)
}

pub fn it_ignores_unknown_settings_test() {
  let headers = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]

  use <- scaffold.open_server(8888, scaffold.uri_echo_handler)

  let actual =
    scaffold.http2_request_after(
      <<0, 0, 6, 4, 0, 0, 0, 0, 0, 0, 9, 0, 0, 0, 1>>,
      headers,
    )

  let expected =
    response.new(200)
    |> response.prepend_header("content-length", "28")
    |> response.set_body(
      bytes_tree.from_bit_array(<<"GET http://example.com:8080/":utf8>>),
    )

  bitstring_response_should_equal(actual, expected)
}

pub fn it_waits_for_window_updates_test() {
  let headers = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]
  let body = <<string.repeat("a", 100_000):utf8>>

  use <- scaffold.open_server(8888, fn(_req) {
    response.new(200)
    |> response.set_body(mist.Bytes(bytes_tree.from_bit_array(body)))
  })

  let actual = scaffold.http2_request(headers)

  let expected =
    response.new(200)
    |> response.prepend_header("content-length", "100000")
    |> response.set_body(bytes_tree.from_bit_array(body))

  bitstring_response_should_equal(actual, expected)
}

pub fn it_sends_go_away_on_malformed_frames_test() {
  let headers = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]

  use <- scaffold.open_server(8888, scaffold.uri_echo_handler)

  let assert [_first, actual] =
    scaffold.http2_requests([
      #(<<>>, headers, <<>>),
      #(<<0, 0, 4, 6, 0, 0, 0, 0, 0, "ping":utf8>>, headers, <<>>),
    ])

  let expected =
    response.new(0)
    |> response.set_body(
      bytes_tree.from_bit_array(<<
        0, 0, 8, 7, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 6,
      >>),
    )

  bitstring_response_should_equal(actual, expected)
}

pub fn it_sends_go_away_on_malformed_headers_test() {
  let headers = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]

  use <- scaffold.open_server(8888, scaffold.uri_echo_handler)

  let assert [_first, actual] =
    scaffold.http2_requests([
      #(<<>>, headers, <<>>),
      #(
        <<0, 0, 6, 1, 5, 0, 0, 0, 3, 255, 255, 255, 255, 255, 255>>,
        headers,
        <<>>,
      ),
    ])

  let expected =
    response.new(0)
    |> response.set_body(
      bytes_tree.from_bit_array(<<
        0, 0, 8, 7, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 9,
      >>),
    )

  bitstring_response_should_equal(actual, expected)
}

pub fn it_sends_server_sent_events_test() {
  let events = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/events"),
  ]
  let headers = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]

  use <- scaffold.open_server(8888, fn(req) {
    case request.path_segments(req) {
      ["events"] ->
        mist.server_sent_events(
          req,
          response.new(200),
          init: fn(subj) {
            process.send(subj, 1)
            process.send(subj, 2)
            process.send(subj, 3)
            Nil
          },
          loop: fn(state, message, conn) {
            let event =
              mist.event(string_tree.from_string(int.to_string(message)))
            let assert Ok(_nil) = mist.send_event(conn, event)
            case message {
              3 -> actor.stop()
              _ -> actor.continue(state)
            }
          },
        )
      _ -> scaffold.uri_echo_handler(req)
    }
  })

  let assert [actual, after] =
    scaffold.http2_requests([#(<<>>, events, <<>>), #(<<>>, headers, <<>>)])

  let expected =
    response.new(200)
    |> response.prepend_header("content-type", "text/event-stream")
    |> response.prepend_header("cache-control", "no-cache")
    |> response.set_body(
      bytes_tree.from_bit_array(<<"data: 1\n\ndata: 2\n\ndata: 3\n\n":utf8>>),
    )

  bitstring_response_should_equal(actual, expected)

  let expected =
    response.new(200)
    |> response.prepend_header("content-length", "28")
    |> response.set_body(
      bytes_tree.from_bit_array(<<"GET http://example.com:8080/":utf8>>),
    )

  bitstring_response_should_equal(after, expected)
}

pub fn it_sends_chunked_responses_test() {
  let headers = [
    #(":method", "POST"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
    #("content-length", "1000"),
  ]
  let body = <<string.repeat("a", 1000):utf8>>

  use <- scaffold.open_server(8888, scaffold.chunked_echo_server(100))

  let assert [actual, after] =
    scaffold.http2_requests([#(<<>>, headers, body), #(<<>>, headers, body)])

  let expected =
    response.new(200)
    |> response.set_body(bytes_tree.from_bit_array(body))

  bitstring_response_should_equal(actual, expected)
  bitstring_response_should_equal(after, expected)
}

pub fn it_sends_file_responses_test() {
  let headers = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]

  use <- scaffold.open_server(8888, fn(_req) {
    let assert Ok(file) =
      mist.send_file("gleam.toml", offset: 8, limit: Some(4))
    response.new(200)
    |> response.set_body(file)
  })

  let assert [actual, after] =
    scaffold.http2_requests([#(<<>>, headers, <<>>), #(<<>>, headers, <<>>)])

  let assert Ok(<<_offset:bytes-size(8), body:bytes-size(4), _rest:bits>>) =
    scaffold.read_file("gleam.toml")
  let expected =
    response.new(200)
    |> response.prepend_header("content-length", "4")
    |> response.set_body(bytes_tree.from_bit_array(body))

  bitstring_response_should_equal(actual, expected)
  bitstring_response_should_equal(after, expected)
}

pub fn it_sends_empty_file_responses_test() {
  let headers = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]

  use <- scaffold.open_server(8888, fn(_req) {
    let assert Ok(file) =
      mist.send_file("gleam.toml", offset: 0, limit: Some(0))
    response.new(200)
    |> response.set_body(file)
  })

  let actual = scaffold.http2_request(headers)

  let expected =
    response.new(200)
    |> response.prepend_header("content-length", "0")
    |> response.set_body(bytes_tree.from_bit_array(<<>>))

  bitstring_response_should_equal(actual, expected)
}

pub fn it_responds_with_500_on_handler_errors_test() {
  let failing = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/fail"),
  ]
  let headers = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]

  use <- scaffold.open_server(8888, fn(req) {
    case request.path_segments(req) {
      ["fail"] -> panic as "handler failed"
      _ -> scaffold.uri_echo_handler(req)
    }
  })

  let assert [actual, after] =
    scaffold.http2_requests([#(<<>>, failing, <<>>), #(<<>>, headers, <<>>)])

  let expected =
    response.new(500)
    |> response.prepend_header("content-length", "21")
    |> response.set_body(
      bytes_tree.from_bit_array(<<"Internal Server Error":utf8>>),
    )

  bitstring_response_should_equal(actual, expected)

  let expected =
    response.new(200)
    |> response.prepend_header("content-length", "28")
    |> response.set_body(
      bytes_tree.from_bit_array(<<"GET http://example.com:8080/":utf8>>),
    )

  bitstring_response_should_equal(after, expected)
}

pub fn it_resets_streams_on_handler_errors_after_headers_test() {
  let failing = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/fail"),
  ]
  let headers = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]

  use <- scaffold.open_server(8888, fn(req) {
    case request.path_segments(req) {
      ["fail"] -> {
        let _response =
          mist.chunked(
            req,
            response.new(200),
            init: fn(subj) { process.send(subj, Nil) },
            loop: fn(_state, _message, _conn) { mist.chunk_stop() },
          )
        panic as "handler failed"
      }
      _ -> scaffold.uri_echo_handler(req)
    }
  })

  let assert [actual, after] =
    scaffold.http2_requests([#(<<>>, failing, <<>>), #(<<>>, headers, <<>>)])

  let expected =
    response.new(200)
    |> response.set_body(bytes_tree.from_bit_array(<<>>))

  bitstring_response_should_equal(actual, expected)

  let expected =
    response.new(200)
    |> response.prepend_header("content-length", "28")
    |> response.set_body(
      bytes_tree.from_bit_array(<<"GET http://example.com:8080/":utf8>>),
    )

  bitstring_response_should_equal(after, expected)
}

pub fn it_reads_bodies_without_content_length_test() {
  let headers = [
    #(":method", "POST"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]

  use <- scaffold.open_server(8888, scaffold.default_handler)

  let actual = scaffold.http2_request_with_body(headers, <<"0123456789":utf8>>)

  let expected =
    response.new(200)
    |> response.prepend_header("host", "example.com:8080")
    |> response.prepend_header("content-length", "10")
    |> response.set_body(bytes_tree.from_bit_array(<<"0123456789":utf8>>))

  bitstring_response_should_equal(actual, expected)
}

pub fn it_limits_bodies_without_content_length_test() {
  let headers = [
    #(":method", "POST"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]

  use <- scaffold.open_server(8888, fn(req) {
    case mist.read_body(req, 9) {
      Ok(_req) -> response.new(200)
      Error(_read_error) -> response.new(413)
    }
    |> response.set_body(mist.Bytes(bytes_tree.new()))
  })

  let actual = scaffold.http2_request_with_body(headers, <<"0123456789":utf8>>)

  let expected =
    response.new(413)
    |> response.prepend_header("content-length", "0")
    |> response.set_body(bytes_tree.from_bit_array(<<>>))

  bitstring_response_should_equal(actual, expected)
}

pub fn it_reads_headers_split_into_frames_test() {
  let headers = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
    #("x-large", string.repeat("a", 20_000)),
  ]

  use <- scaffold.open_server(8888, fn(req) {
    let assert Ok(large) = request.get_header(req, "x-large")
    response.new(200)
    |> response.set_body(
      mist.Bytes(bytes_tree.from_string(int.to_string(string.length(large)))),
    )
  })

  let actual = scaffold.http2_request(headers)

  let expected =
    response.new(200)
    |> response.prepend_header("content-length", "5")
    |> response.set_body(bytes_tree.from_bit_array(<<"20000":utf8>>))

  bitstring_response_should_equal(actual, expected)
}

pub fn it_sends_go_away_on_frames_inside_headers_test() {
  let headers = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]

  use <- scaffold.open_server(8888, scaffold.uri_echo_handler)

  let assert [_first, actual] =
    scaffold.http2_requests([
      #(<<>>, headers, <<>>),
      #(
        <<
          0, 0, 1, 1, 1, 0, 0, 0, 3, 0, 0, 0, 8, 6, 0, 0, 0, 0, 0,
          "pingping":utf8,
        >>,
        headers,
        <<>>,
      ),
    ])

  let expected =
    response.new(0)
    |> response.set_body(
      bytes_tree.from_bit_array(<<
        0, 0, 8, 7, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1,
      >>),
    )

  bitstring_response_should_equal(actual, expected)
}

pub fn it_reads_bodies_ended_by_trailers_test() {
  let headers = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]
  let trailers = [#("x-checksum", "abc")]

  use <- scaffold.open_server(8888, scaffold.default_handler)

  let assert [_first, actual] =
    scaffold.http2_requests([
      #(<<>>, headers, <<>>),
      #(
        <<
          0, 0, 66, 1, 4, 0, 0, 0, 3, 0, 7, ":method":utf8, 4, "POST":utf8, 0, 7,
          ":scheme":utf8, 4, "http":utf8, 0, 10, ":authority":utf8, 16,
          "example.com:8080":utf8, 0, 5, ":path":utf8, 1, "/":utf8, 0, 0, 10, 0,
          0, 0, 0, 0, 3, "0123456789":utf8,
        >>,
        trailers,
        <<>>,
      ),
    ])

  let expected =
    response.new(200)
    |> response.prepend_header("host", "example.com:8080")
    |> response.prepend_header("content-length", "10")
    |> response.set_body(bytes_tree.from_bit_array(<<"0123456789":utf8>>))

  bitstring_response_should_equal(actual, expected)
}

pub fn it_sends_go_away_on_oversized_frames_test() {
  let headers = [
    #(":method", "POST"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]
  let body = <<string.repeat("a", 16_385):utf8>>

  use <- scaffold.open_server(8888, scaffold.default_handler)

  let actual = scaffold.http2_request_with_body(headers, body)

  let expected =
    response.new(0)
    |> response.set_body(
      bytes_tree.from_bit_array(<<
        0, 0, 8, 7, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 6,
      >>),
    )

  bitstring_response_should_equal(actual, expected)
}

fn chunk_events_handler(
  events: process.Subject(String),
) -> fn(request.Request(mist.Connection)) ->
  response.Response(mist.ResponseData) {
  fn(req) {
    mist.chunked(
      req,
      response.new(200),
      init: fn(subj) { process.send(subj, Nil) },
      loop: fn(_state, _message, conn) {
        process.send(events, "sending")
        case mist.send_chunk(conn, <<"chunk":utf8>>) {
          Ok(_nil) -> process.send(events, "sent")
          Error(_nil) -> process.send(events, "failed")
        }
        mist.chunk_stop()
      },
    )
  }
}

pub fn it_waits_for_the_window_before_sending_more_chunks_test() {
  let headers = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]
  let events = process.new_subject()

  use <- scaffold.open_server(8888, chunk_events_handler(events))

  let socket = scaffold.http2_open([frame.InitialWindowSize(0)], headers)
  let assert Ok("sending") = process.receive(events, 1000)
  let waiting = process.receive(events, 100)
  scaffold.http2_send(
    socket,
    frame.WindowUpdate(amount: 1000, identifier: frame.stream_identifier(1)),
  )
  let assert Ok("sent") = process.receive(events, 1000)

  assert waiting == Error(Nil)
}

pub fn it_fails_sends_on_reset_streams_test() {
  let headers = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]
  let events = process.new_subject()

  use <- scaffold.open_server(8888, chunk_events_handler(events))

  let socket = scaffold.http2_open([frame.InitialWindowSize(0)], headers)
  let assert Ok("sending") = process.receive(events, 1000)
  scaffold.http2_send(
    socket,
    frame.Termination(
      error: frame.Cancel,
      identifier: frame.stream_identifier(1),
    ),
  )

  assert process.receive(events, 1000) == Ok("failed")
}

pub fn it_stops_the_handler_when_a_stream_is_reset_test() {
  let headers = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]
  let started = process.new_subject()

  use <- scaffold.open_server(8888, fn(_req) {
    process.send(started, process.self())
    process.sleep_forever()
    response.new(200)
    |> response.set_body(mist.Bytes(bytes_tree.new()))
  })

  let socket = scaffold.http2_open([], headers)
  let assert Ok(handler) = process.receive(started, 1000)
  let monitor = process.monitor(handler)
  scaffold.http2_send(
    socket,
    frame.Header(
      data: frame.Complete(<<0, 10, "x-checksum":utf8, 3, "abc":utf8>>),
      end_stream: True,
      identifier: frame.stream_identifier(1),
      priority: option.None,
    ),
  )

  let stopped =
    process.new_selector()
    |> process.select_specific_monitor(monitor, fn(_down) { Nil })
    |> process.selector_receive(1000)

  assert stopped == Ok(Nil)
}

pub fn it_cancels_sends_that_time_out_test() {
  let headers = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]
  let events = process.new_subject()

  use <- scaffold.open_server_with_send_timeout(
    8888,
    chunk_events_handler(events),
    100,
  )

  let socket = scaffold.http2_open([frame.InitialWindowSize(0)], headers)
  let assert Ok("sending") = process.receive(events, 1000)
  let assert Ok("failed") = process.receive(events, 1000)
  scaffold.http2_send(
    socket,
    frame.WindowUpdate(amount: 1000, identifier: frame.stream_identifier(1)),
  )
  let received =
    scaffold.http2_receive(socket)
    |> list.filter(fn(received) {
      case received {
        frame.Settings(..) | frame.Header(..) -> False
        _frame -> True
      }
    })

  assert received
    == [
      frame.Termination(
        error: frame.Cancel,
        identifier: frame.stream_identifier(1),
      ),
    ]
}

pub fn it_times_out_sends_after_the_send_timeout_test() {
  let headers = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]
  let events = process.new_subject()

  use <- scaffold.start_server(
    mist.new(chunk_events_handler(events))
    |> mist.port(8888)
    |> mist.with_send_timeout(100),
  )

  let _socket = scaffold.http2_open([frame.InitialWindowSize(0)], headers)
  let assert Ok("sending") = process.receive(events, 1000)
  let sent = process.receive(events, 1000)

  assert sent == Ok("failed")
}

pub fn it_sends_go_away_on_reused_stream_ids_test() {
  let headers = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]

  use <- scaffold.open_server(8888, scaffold.uri_echo_handler)

  let assert [_first, actual] =
    scaffold.http2_requests([
      #(<<>>, headers, <<>>),
      #(
        <<
          0, 0, 21, 1, 5, 0, 0, 0, 1, 130, 134, 132, 1, 16,
          "example.com:8080":utf8,
        >>,
        headers,
        <<>>,
      ),
    ])

  let expected =
    response.new(0)
    |> response.set_body(
      bytes_tree.from_bit_array(<<
        0, 0, 8, 7, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1,
      >>),
    )

  bitstring_response_should_equal(actual, expected)
}

pub fn it_sends_go_away_on_continuation_without_headers_test() {
  let headers = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]

  use <- scaffold.open_server(8888, scaffold.uri_echo_handler)

  let assert [_first, actual] =
    scaffold.http2_requests([
      #(<<>>, headers, <<>>),
      #(<<0, 0, 1, 9, 4, 0, 0, 0, 3, 0>>, headers, <<>>),
    ])

  let expected =
    response.new(0)
    |> response.set_body(
      bytes_tree.from_bit_array(<<
        0, 0, 8, 7, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1,
      >>),
    )

  bitstring_response_should_equal(actual, expected)
}

pub fn it_sends_go_away_on_oversized_header_blocks_test() {
  let headers = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]
  let fragment = <<string.repeat("a", 16_384):utf8>>
  let header =
    frame.encode(frame.Header(
      data: frame.Continued(fragment),
      end_stream: True,
      identifier: frame.stream_identifier(3),
      priority: option.None,
    ))
  let continuation =
    frame.encode(frame.Continuation(
      data: frame.Continued(fragment),
      identifier: frame.stream_identifier(3),
    ))

  use <- scaffold.open_server(8888, scaffold.uri_echo_handler)

  let assert [_first, actual] =
    scaffold.http2_requests([
      #(<<>>, headers, <<>>),
      #(
        <<
          header:bits, continuation:bits, continuation:bits, continuation:bits,
          0, 0, 1, 9, 0, 0, 0, 0, 3, 97,
        >>,
        headers,
        <<>>,
      ),
    ])

  let expected =
    response.new(0)
    |> response.set_body(
      bytes_tree.from_bit_array(<<
        0, 0, 8, 7, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 11,
      >>),
    )

  bitstring_response_should_equal(actual, expected)
}

pub fn it_resets_streams_with_wrong_content_length_test() {
  let headers = [
    #(":method", "POST"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
    #("content-length", "5"),
  ]

  use <- scaffold.open_server(8888, scaffold.default_handler)

  let actual = scaffold.http2_request_with_body(headers, <<"0123456789":utf8>>)

  let expected =
    response.new(0)
    |> response.set_body(bytes_tree.from_bit_array(<<>>))

  bitstring_response_should_equal(actual, expected)
}

pub fn it_resets_trailers_with_wrong_content_length_test() {
  let headers = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]

  use <- scaffold.open_server(8888, scaffold.default_handler)

  let socket = scaffold.http2_open([], headers)
  scaffold.http2_send(
    socket,
    frame.Header(
      data: frame.Complete(<<
        0, 7, ":method":utf8, 4, "POST":utf8, 0, 7, ":scheme":utf8, 4,
        "http":utf8, 0, 10, ":authority":utf8, 16, "example.com:8080":utf8, 0, 5,
        ":path":utf8, 1, "/":utf8, 0, 14, "content-length":utf8, 1, "5":utf8,
      >>),
      end_stream: False,
      identifier: frame.stream_identifier(3),
      priority: option.None,
    ),
  )
  scaffold.http2_send(
    socket,
    frame.Data(
      data: <<"012":utf8>>,
      end_stream: False,
      identifier: frame.stream_identifier(3),
    ),
  )
  scaffold.http2_send(
    socket,
    frame.Header(
      data: frame.Complete(<<0, 10, "x-checksum":utf8, 3, "abc":utf8>>),
      end_stream: True,
      identifier: frame.stream_identifier(3),
      priority: option.None,
    ),
  )
  let received =
    scaffold.http2_receive(socket)
    |> list.filter(fn(received) {
      case received {
        frame.Termination(..) -> True
        _frame -> False
      }
    })

  assert received
    == [
      frame.Termination(
        error: frame.ProtocolError,
        identifier: frame.stream_identifier(3),
      ),
    ]
}

pub fn it_resets_streams_with_content_length_and_no_body_test() {
  let headers = [
    #(":method", "POST"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
    #("content-length", "5"),
  ]
  let started = process.new_subject()

  use <- scaffold.open_server(8888, fn(_req) {
    process.send(started, Nil)
    response.new(200)
    |> response.set_body(mist.Bytes(bytes_tree.new()))
  })

  let socket = scaffold.http2_open([], headers)
  let received =
    scaffold.http2_receive(socket)
    |> list.filter(fn(received) {
      case received {
        frame.Termination(..) -> True
        _frame -> False
      }
    })

  assert received
    == [
      frame.Termination(
        error: frame.ProtocolError,
        identifier: frame.stream_identifier(1),
      ),
    ]
  assert process.receive(started, 100) == Error(Nil)
}

pub fn it_keeps_the_connection_after_content_length_without_a_body_test() {
  let headers = [
    #(":method", "POST"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]

  use <- scaffold.open_server(8888, scaffold.uri_echo_handler)

  let assert [reset, actual] =
    scaffold.http2_requests([
      #(<<>>, [#("content-length", "5"), ..headers], <<>>),
      #(<<>>, [#("content-length", "0"), ..headers], <<>>),
    ])

  let expected =
    response.new(200)
    |> response.prepend_header("content-length", "29")
    |> response.set_body(bytes_tree.from_string("POST http://example.com:8080/"))

  assert reset.status == 0
  bitstring_response_should_equal(actual, expected)
}

pub fn it_counts_streams_reset_for_content_length_without_a_body_test() {
  let headers = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]

  use <- scaffold.open_server(8888, scaffold.uri_echo_handler)

  let assert [reset, actual] =
    scaffold.http2_requests([
      #(<<>>, [#("content-length", "5"), ..headers], <<>>),
      #(
        <<
          0, 0, 21, 1, 5, 0, 0, 0, 1, 130, 134, 132, 1, 16,
          "example.com:8080":utf8,
        >>,
        headers,
        <<>>,
      ),
    ])

  let expected =
    response.new(0)
    |> response.set_body(
      bytes_tree.from_bit_array(<<
        0, 0, 8, 7, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1,
      >>),
    )

  assert reset.status == 0
  bitstring_response_should_equal(actual, expected)
}

pub fn it_resets_data_on_half_closed_streams_test() {
  let headers = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]
  let started = process.new_subject()

  use <- scaffold.open_server(8888, fn(_req) {
    process.send(started, Nil)
    process.sleep_forever()
    response.new(200)
    |> response.set_body(mist.Bytes(bytes_tree.new()))
  })

  let socket = scaffold.http2_open([], headers)
  let assert Ok(Nil) = process.receive(started, 1000)
  scaffold.http2_send(
    socket,
    frame.Data(
      data: <<"012":utf8>>,
      end_stream: False,
      identifier: frame.stream_identifier(1),
    ),
  )
  let received =
    scaffold.http2_receive(socket)
    |> list.filter(fn(received) {
      case received {
        frame.Termination(..) -> True
        _frame -> False
      }
    })

  assert received
    == [
      frame.Termination(
        error: frame.StreamClosed,
        identifier: frame.stream_identifier(1),
      ),
    ]
}

fn post_headers(identifier: Int) -> frame.Frame {
  frame.Header(
    data: frame.Complete(<<
      0, 7, ":method":utf8, 4, "POST":utf8, 0, 5, ":path":utf8, 1, "/":utf8, 0,
      7, ":scheme":utf8, 4, "http":utf8, 0, 10, ":authority":utf8, 16,
      "example.com:8080":utf8,
    >>),
    end_stream: False,
    identifier: frame.stream_identifier(identifier),
    priority: option.None,
  )
}

fn stream_window_updates(
  frames: List(frame.Frame),
  identifier: Int,
) -> List(Int) {
  let identifier = frame.stream_identifier(identifier)
  list.filter_map(frames, fn(received) {
    case received {
      frame.WindowUpdate(amount: amount, identifier: stream)
        if stream == identifier
      -> Ok(amount)
      _frame -> Error(Nil)
    }
  })
}

pub fn it_grants_the_stream_window_as_the_body_is_read_test() {
  let headers = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]
  let started = process.new_subject()
  let read = process.new_subject()

  use <- scaffold.open_server(8888, fn(req) {
    case req.method {
      http.Post -> {
        let reading = process.new_subject()
        process.send(started, reading)
        process.receive_forever(reading)
        process.send(read, mist.read_body(req, 32_768))
      }
      _method -> Nil
    }
    response.new(200)
    |> response.set_body(mist.Bytes(bytes_tree.new()))
  })

  let socket = scaffold.http2_open([], headers)
  scaffold.http2_send(socket, post_headers(3))
  let assert Ok(reading) = process.receive(started, 1000)
  list.each([<<0:size(131_072)>>, <<0:size(131_072)>>, <<0>>], fn(data) {
    scaffold.http2_send(
      socket,
      frame.Data(
        data: data,
        end_stream: False,
        identifier: frame.stream_identifier(3),
      ),
    )
  })
  let unread = stream_window_updates(scaffold.http2_receive(socket), 3)
  process.send(reading, Nil)
  let assert Ok(Error(mist.ExcessBody)) = process.receive(read, 1000)
  let consumed = stream_window_updates(scaffold.http2_receive(socket), 3)

  assert unread == []
  assert consumed == [32_768]
}

pub fn it_reads_bodies_larger_than_the_stream_window_test() {
  let headers = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]
  let read = process.new_subject()

  use <- scaffold.open_server(8888, fn(req) {
    let assert Ok(req) = mist.read_body(req, 1_000_000)
    process.send(read, bit_array.byte_size(req.body))
    response.new(200)
    |> response.set_body(mist.Bytes(bytes_tree.new()))
  })

  let socket = scaffold.http2_open([], headers)
  let assert Ok(0) = process.receive(read, 1000)
  scaffold.http2_send(socket, post_headers(3))
  scaffold.http2_send_body(socket, 3, <<0:size(1_600_000)>>)

  assert process.receive(read, 1000) == Ok(200_000)
}

pub fn it_resets_streams_that_exceed_the_receive_window_test() {
  let headers = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]

  use <- scaffold.open_server(8888, fn(_req) {
    process.sleep_forever()
    response.new(200)
    |> response.set_body(mist.Bytes(bytes_tree.new()))
  })

  let socket = scaffold.http2_open([], headers)
  scaffold.http2_send(socket, post_headers(3))
  list.each([1, 2, 3, 4], fn(_frame) {
    scaffold.http2_send(
      socket,
      frame.Data(
        data: <<0:size(131_072)>>,
        end_stream: False,
        identifier: frame.stream_identifier(3),
      ),
    )
  })
  let received =
    scaffold.http2_receive(socket)
    |> list.filter(fn(received) {
      case received {
        frame.Termination(..) -> True
        _frame -> False
      }
    })

  assert received
    == [
      frame.Termination(
        error: frame.FlowControlError,
        identifier: frame.stream_identifier(3),
      ),
    ]
}

fn wait_for_handler(started: process.Subject(process.Pid)) -> Nil {
  let assert Ok(handler) = process.receive(started, 1000)
  let monitor = process.monitor(handler)
  let assert Ok(Nil) =
    process.new_selector()
    |> process.select_specific_monitor(monitor, fn(_down) { Nil })
    |> process.selector_receive(1000)
  Nil
}

fn stream_frames(
  frames: List(frame.Frame),
  identifier: Int,
) -> List(frame.Frame) {
  let identifier = frame.stream_identifier(identifier)
  list.filter(frames, fn(received) {
    case received {
      frame.Header(identifier: stream, ..)
      | frame.Data(identifier: stream, ..)
      | frame.Termination(identifier: stream, ..) -> stream == identifier
      _frame -> False
    }
  })
}

pub fn it_closes_streams_answered_before_the_body_ends_test() {
  let headers = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]
  let started = process.new_subject()

  use <- scaffold.open_server(8888, fn(_req) {
    process.send(started, process.self())
    response.new(200)
    |> response.set_body(mist.Bytes(bytes_tree.new()))
  })

  let socket = scaffold.http2_open([], headers)
  wait_for_handler(started)
  scaffold.http2_send(socket, post_headers(3))
  wait_for_handler(started)
  let answered = stream_frames(scaffold.http2_receive(socket), 3)
  scaffold.http2_send(
    socket,
    frame.Header(
      data: frame.Complete(<<
        0, 7, ":method":utf8, 3, "GET":utf8, 0, 5, ":path":utf8, 1, "/":utf8, 0,
        7, ":scheme":utf8, 4, "http":utf8, 0, 10, ":authority":utf8, 16,
        "example.com:8080":utf8,
      >>),
      end_stream: True,
      identifier: frame.stream_identifier(5),
      priority: option.None,
    ),
  )
  wait_for_handler(started)
  let next = stream_frames(scaffold.http2_receive(socket), 5)

  let assert [frame.Header(end_stream: True, ..), reset] = answered
  assert reset
    == frame.Termination(
      error: frame.NoError,
      identifier: frame.stream_identifier(3),
    )
  let assert [frame.Header(end_stream: True, ..)] = next
}

pub fn it_grants_the_stream_window_for_padding_test() {
  let headers = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]
  let read = process.new_subject()

  use <- scaffold.open_server(8888, fn(req) {
    case req.method {
      http.Post -> process.send(read, mist.read_body(req, 32_256))
      _method -> Nil
    }
    response.new(200)
    |> response.set_body(mist.Bytes(bytes_tree.new()))
  })

  let socket = scaffold.http2_open([], headers)
  scaffold.http2_send(socket, post_headers(3))
  scaffold.http2_send_padded(socket, 3, <<0:size(129_024)>>, 255)
  scaffold.http2_send_padded(socket, 3, <<0:size(129_024)>>, 255)
  scaffold.http2_send(
    socket,
    frame.Data(
      data: <<0>>,
      end_stream: False,
      identifier: frame.stream_identifier(3),
    ),
  )
  let assert Ok(Error(mist.ExcessBody)) = process.receive(read, 1000)
  let updates = stream_window_updates(scaffold.http2_receive(socket), 3)

  assert updates == [32_768]
}

pub fn it_counts_padding_against_the_receive_window_test() {
  let headers = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]

  use <- scaffold.open_server(8888, fn(_req) {
    process.sleep_forever()
    response.new(200)
    |> response.set_body(mist.Bytes(bytes_tree.new()))
  })

  let socket = scaffold.http2_open([], headers)
  scaffold.http2_send(socket, post_headers(3))
  list.each([1, 2, 3, 4], fn(_frame) {
    scaffold.http2_send(
      socket,
      frame.Data(
        data: <<0:size(131_064)>>,
        end_stream: False,
        identifier: frame.stream_identifier(3),
      ),
    )
  })
  scaffold.http2_send_padded(socket, 3, <<0>>, 2)
  let received =
    scaffold.http2_receive(socket)
    |> list.filter(fn(received) {
      case received {
        frame.Termination(..) -> True
        _frame -> False
      }
    })

  assert received
    == [
      frame.Termination(
        error: frame.FlowControlError,
        identifier: frame.stream_identifier(3),
      ),
    ]
}

fn release_handler(release: process.Subject(Nil)) -> Nil {
  let assert Ok(handler) = process.subject_owner(release)
  let monitor = process.monitor(handler)
  process.send(release, Nil)
  let assert Ok(Nil) =
    process.new_selector()
    |> process.select_specific_monitor(monitor, fn(_down) { Nil })
    |> process.selector_receive(1000)
  Nil
}

pub fn it_refuses_streams_over_the_concurrent_stream_limit_test() {
  let headers = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]
  let started = process.new_subject()

  use <- scaffold.open_server(8888, fn(_req) {
    let release = process.new_subject()
    process.send(started, release)
    process.receive_forever(release)
    response.new(200)
    |> response.set_body(mist.Bytes(bytes_tree.new()))
  })

  let socket = scaffold.http2_open([], headers)
  let assert Ok(first) = process.receive(started, 1000)
  int.range(from: 1, to: 100, with: Nil, run: fn(_nil, n) {
    scaffold.http2_send(socket, post_headers(n * 2 + 1))
  })
  list.each(list.repeat(Nil, 99), fn(_nil) {
    let assert Ok(_release) = process.receive(started, 1000)
  })
  scaffold.http2_send(socket, post_headers(201))
  let refused = stream_frames(scaffold.http2_receive(socket), 201)
  release_handler(first)
  scaffold.http2_send(socket, post_headers(203))
  let assert Ok(last) = process.receive(started, 1000)
  release_handler(last)
  let accepted = stream_frames(scaffold.http2_receive(socket), 203)

  assert refused
    == [
      frame.Termination(
        error: frame.RefusedStream,
        identifier: frame.stream_identifier(201),
      ),
    ]
  let assert [
    frame.Header(end_stream: True, ..),
    frame.Termination(error: frame.NoError, ..),
  ] = accepted
}

pub fn it_waits_for_slow_request_bodies_test() {
  let headers = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]
  let read = process.new_subject()

  use <- scaffold.open_server(8888, fn(req) {
    case req.method {
      http.Post -> process.send(read, mist.read_body(req, 1000))
      _method -> Nil
    }
    response.new(200)
    |> response.set_body(mist.Bytes(bytes_tree.new()))
  })

  let socket = scaffold.http2_open([], headers)
  scaffold.http2_send(socket, post_headers(3))
  scaffold.http2_send(
    socket,
    frame.Data(
      data: <<"012":utf8>>,
      end_stream: False,
      identifier: frame.stream_identifier(3),
    ),
  )
  process.sleep(1200)
  scaffold.http2_send(
    socket,
    frame.Data(
      data: <<"345":utf8>>,
      end_stream: True,
      identifier: frame.stream_identifier(3),
    ),
  )
  let assert Ok(Ok(req)) = process.receive(read, 1000)

  assert req.body == <<"012345":utf8>>
}

pub fn it_times_out_slow_request_bodies_test() {
  let headers = [
    #(":method", "GET"),
    #(":scheme", "http"),
    #(":authority", "example.com:8080"),
    #(":path", "/"),
  ]
  let read = process.new_subject()

  use <- scaffold.start_server(
    mist.new(fn(req) {
      case req.method {
        http.Post -> process.send(read, mist.read_body(req, 1000))
        _method -> Nil
      }
      response.new(200)
      |> response.set_body(mist.Bytes(bytes_tree.new()))
    })
    |> mist.port(8888)
    |> mist.with_read_timeout(200),
  )

  let socket = scaffold.http2_open([], headers)
  scaffold.http2_send(socket, post_headers(3))
  scaffold.http2_send(
    socket,
    frame.Data(
      data: <<"012":utf8>>,
      end_stream: False,
      identifier: frame.stream_identifier(3),
    ),
  )
  process.sleep(400)
  scaffold.http2_send(
    socket,
    frame.Data(
      data: <<"345":utf8>>,
      end_stream: True,
      identifier: frame.stream_identifier(3),
    ),
  )
  let assert Ok(result) = process.receive(read, 1000)

  assert result == Error(mist.MalformedBody)
}
