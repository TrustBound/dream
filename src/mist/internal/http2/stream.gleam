import exception
import gleam/bytes_tree
import gleam/erlang/process.{type Selector, type Subject}
import gleam/http.{type Header} as ghttp
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/pair
import gleam/result
import gleam/string
import gleam/uri
import logging
import mist/internal/file
import mist/internal/http.{
  type Connection, type Handler, type ResponseData, Bytes, Connection, File,
  Stream,
}
import mist/internal/http2/frame.{type Frame, type StreamIdentifier}

pub type Message {
  Ready
  Data(bits: BitArray, end: Bool)
}

pub type SendMessage {
  Send(identifier: StreamIdentifier(Frame), resp: Response(ResponseData))
  Reset(identifier: StreamIdentifier(Frame), error: frame.ConnectionError)
  SendHeaders(
    identifier: StreamIdentifier(Frame),
    status: Int,
    headers: List(Header),
  )
  SendData(
    identifier: StreamIdentifier(Frame),
    data: BitArray,
    sent: Subject(Result(Nil, Nil)),
  )
  ConsumeData(identifier: StreamIdentifier(Frame), size: Int)
}

pub type StreamState {
  Open
  RemoteClosed
  Closed
}

pub type State {
  State(
    id: StreamIdentifier(Frame),
    state: StreamState,
    subject: Subject(Message),
    receive_window_size: Int,
    consumed_size: Int,
    send_window_size: Int,
    pending_content_length: Option(Int),
    headers_sent: Bool,
  )
}

pub type InternalState {
  InternalState(data_selector: Selector(Message))
}

pub fn new(
  identifier: StreamIdentifier(Frame),
  handler: Handler,
  headers: List(Header),
  connection: Connection,
  sender: Subject(SendMessage),
  end: Bool,
  send_timeout: Int,
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
        let self = process.self()
        let conn =
          Connection(
            ..connection,
            body: Stream(
              selector: process.map_selector(state.data_selector, fn(val) {
                let assert Data(bits, end) = val
                #(bits, end)
              }),
              attempts: 0,
              data: <<>>,
              end: end,
              send_headers: fn(status, headers) {
                process.send(sender, SendHeaders(identifier, status, headers))
              },
              send_data: fn(data) {
                let open =
                  process.subject_owner(sender)
                  |> result.map(process.is_alive)
                  |> result.unwrap(False)
                case open && process.is_alive(self) {
                  True -> send_data(sender, identifier, data, send_timeout)
                  False -> Error(Nil)
                }
              },
              consume_data: fn(size) {
                process.send(sender, ConsumeData(identifier, size))
              },
            ),
          )

        let result =
          request.new()
          |> request.set_body(conn)
          |> make_request(headers, _)

        case result {
          Ok(value) -> {
            let resp = case parse_host(value) {
              Ok(req) ->
                case exception.rescue(fn() { handler(req) }) {
                  Ok(resp) -> resp
                  Error(error) -> {
                    logging.log(logging.Error, string.inspect(error))
                    response.new(500)
                    |> response.set_body(
                      Bytes(
                        bytes_tree.from_bit_array(<<
                          "Internal Server Error":utf8,
                        >>),
                      ),
                    )
                  }
                }
              Error(_nil) -> {
                logging.log(logging.Debug, "Missing HTTP `host` header")
                response.new(400)
                |> response.set_body(Bytes(bytes_tree.new()))
              }
            }
            case resp.body {
              File(..) -> send_file_body(sender, identifier, resp)
              _ -> process.send(sender, Send(identifier, resp))
            }
            actor.stop()
          }
          Error(_nil) -> {
            logging.log(logging.Debug, "Invalid HTTP/2 request")
            process.send(sender, Reset(identifier, frame.ProtocolError))
            actor.stop()
          }
        }
      }
      _msg -> actor.continue(state)
    }
  })
  |> actor.start
}

fn send_data(
  sender: Subject(SendMessage),
  identifier: StreamIdentifier(Frame),
  data: BitArray,
  timeout: Int,
) -> Result(Nil, Nil) {
  use connection <- result.try(process.subject_owner(sender))
  let monitor = process.monitor(connection)
  let sent = process.new_subject()
  process.send(sender, SendData(identifier, data, sent))
  let selector =
    process.new_selector()
    |> process.select(sent)
    |> process.select_specific_monitor(monitor, fn(_down) { Error(Nil) })
  let reply = case process.selector_receive(selector, timeout) {
    Ok(reply) -> reply
    Error(_nil) -> {
      process.send(sender, Reset(identifier, frame.Cancel))
      let _ = process.selector_receive(selector, timeout)
      Error(Nil)
    }
  }
  process.demonitor_process(monitor)
  reply
}

fn send_file_body(
  sender: Subject(SendMessage),
  identifier: StreamIdentifier(Frame),
  resp: Response(ResponseData),
) -> Nil {
  let assert File(file_descriptor, offset, length) = resp.body
  let read = file.pread(file_descriptor, offset, length)

  case file.close(file_descriptor) {
    Ok(_nil) -> Nil
    Error(reason) -> {
      logging.log(
        logging.Error,
        "Failed to close file: " <> file.error_to_string(reason),
      )
    }
  }

  case read {
    Ok(bits) -> {
      let resp = response.set_body(resp, Bytes(bytes_tree.from_bit_array(bits)))
      process.send(sender, Send(identifier, resp))
    }
    Error(reason) -> {
      logging.log(
        logging.Error,
        "Failed to send file: " <> file.error_to_string(reason),
      )
      process.send(sender, Reset(identifier, frame.InternalError))
    }
  }
}

pub fn make_request(
  headers: List(Header),
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
      |> request.set_header("host", authority)
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

fn parse_host(req: Request(Connection)) -> Result(Request(Connection), Nil) {
  req
  |> request.get_header("host")
  |> result.map(fn(host_header) {
    let #(hostname, port) =
      host_header
      |> string.split_once(":")
      |> result.unwrap(#(host_header, ""))

    let port = case int.parse(port) {
      Ok(port) -> port
      Error(_) ->
        case req.scheme {
          ghttp.Https -> 443
          ghttp.Http -> 80
        }
    }

    req
    |> request.set_host(hostname)
    |> request.set_port(port)
  })
}

pub fn receive_data(state: State, length: Int, size: Int) -> State {
  State(
    ..state,
    receive_window_size: state.receive_window_size - length,
    pending_content_length: option.map(state.pending_content_length, fn(val) {
      val - size
    }),
  )
}
