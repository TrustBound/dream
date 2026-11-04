import gleam/bytes_tree.{type BytesTree}
import gleam/erlang/process.{type Selector, type Subject}
import gleam/http as ghttp
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/pair
import gleam/result
import gleam/string
import gleam/uri
import mist/internal/http.{
  type Connection, type Handler, type ResponseData, Connection, H2StreamSender,
  Stream,
}
import mist/internal/http2/flow_control
import mist/internal/http2/frame.{type Frame, type StreamIdentifier}

pub type Message {
  Ready
  Data(bits: BitArray, end: Bool)
}

pub type SendMessage {
  Send(identifier: StreamIdentifier(Frame), resp: Response(ResponseData))
  StreamHeaders(
    identifier: StreamIdentifier(Frame),
    status: Int,
    headers: List(#(String, String)),
  )
  StreamData(
    identifier: StreamIdentifier(Frame),
    data: BytesTree,
    end_stream: Bool,
  )
}

pub type StreamState {
  Open
  RemoteClosed
  LocalClosed
  Closed
}

pub type State {
  State(
    id: StreamIdentifier(Frame),
    state: StreamState,
    subject: Subject(Message),
    receive_window_size: Int,
    send_window_size: Int,
    pending_content_length: Option(Int),
  )
}

pub type InternalState {
  InternalState(data_selector: Selector(Message))
}

pub fn new(
  identifier: StreamIdentifier(Frame),
  handler: Handler,
  headers: List(#(String, String)),
  connection: Connection,
  sender: Subject(SendMessage),
) -> Result(actor.Started(Subject(Message)), actor.StartError) {
  actor.new_with_initialiser(1000, fn(subject) {
    let data_selector =
      process.new_selector()
      |> process.select(subject)
    InternalState(data_selector)
    |> actor.initialised
    |> actor.selecting(data_selector)
    |> actor.returning(subject)
    |> Ok
  })
  |> actor.on_message(fn(state, msg) {
    case msg {
      Ready -> {
        let content_length =
          headers
          |> list.key_find("content-length")
          |> result.try(int.parse)
          |> result.unwrap(0)
        let h2_sender =
          H2StreamSender(
            send_headers: fn(status, hdrs) {
              process.send(sender, StreamHeaders(identifier, status, hdrs))
            },
            send_data: fn(data, end_stream) {
              process.send(sender, StreamData(identifier, data, end_stream))
            },
          )
        let conn =
          Connection(
            ..connection,
            h2_sender: Some(h2_sender),
            body: Stream(
              selector: process.map_selector(state.data_selector, fn(val) {
                let assert Data(bits, ..) = val
                bits
              }),
              attempts: 0,
              data: <<>>,
              remaining: content_length,
            ),
          )

        let result =
          request.new()
          |> request.set_body(conn)
          |> make_request(headers, _)

        case result {
          Ok(value) -> {
            let resp = handler(value)
            process.send(sender, Send(identifier, resp))
            actor.stop()
          }
          Error(err) ->
            actor.stop_abnormal(
              "Failed to respond to request: " <> string.inspect(err),
            )
        }
      }
      _ -> actor.continue(state)
    }
  })
  |> actor.start
}

pub fn make_request(
  headers: List(#(String, String)),
  req: Request(Connection),
) -> Result(Request(Connection), Nil) {
  case headers {
    [] -> Ok(req)
    [#(":method", method), ..rest] -> {
      method
      |> ghttp.parse_method
      |> result.replace_error(Nil)
      |> result.map(request.set_method(req, _))
      |> result.try(make_request(rest, _))
    }
    [#(":scheme", scheme), ..rest] -> {
      scheme
      |> ghttp.scheme_from_string
      |> result.replace_error(Nil)
      |> result.map(request.set_scheme(req, _))
      |> result.try(make_request(rest, _))
    }
    [#(":authority", authority), ..rest] -> {
      req
      |> request.set_host(authority)
      |> make_request(rest, _)
    }
    [#(":path", path), ..rest] -> {
      path
      |> string.split_once(on: "?")
      |> result.map(fn(split) {
        pair.map_second(split, fn(query) {
          query
          |> uri.parse_query
          |> result.map(Some)
          |> result.unwrap(None)
        })
      })
      |> result.unwrap(#(path, None))
      |> fn(tup: #(String, Option(List(#(String, String))))) {
        case tup.1 {
          Some(query) ->
            req
            |> request.set_path(tup.0)
            |> request.set_query(query)
          _ -> request.set_path(req, tup.0)
        }
        |> make_request(rest, _)
      }
    }
    [#(key, value), ..rest] ->
      req
      |> request.set_header(key, value)
      |> make_request(rest, _)
  }
}

pub fn receive_data(state: State, size: Int) -> #(State, Int) {
  let #(new_window_size, increment) =
    flow_control.compute_receive_window(state.receive_window_size, size)

  let new_state =
    State(
      ..state,
      receive_window_size: new_window_size,
      pending_content_length: option.map(state.pending_content_length, fn(val) {
        val - size
      }),
    )

  #(new_state, increment)
}
