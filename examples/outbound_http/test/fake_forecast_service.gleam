//// A fake forecast service for the tests: a small Dream server on
//// localhost, with one city for each answer that the app must handle.

import dream/context.{type EmptyContext, EmptyContext}
import dream/http.{require_string}
import dream/http/error
import dream/http/request.{type Request, Get, Post}
import dream/http/response.{
  type Response, json_response, stream_response, text_response,
}
import dream/router.{type Router, route, router}
import dream/servers/mist/server.{type ServerHandle}
import gleam/dynamic/decode
import gleam/erlang/process.{type Subject}
import gleam/json
import gleam/result
import gleam/string
import gleam/yielder

/// `slow_requests` gets a subject from each request for the city `slow`.
/// The request answers when a message comes on that subject.
pub type FakeServices {
  FakeServices(slow_requests: Subject(Subject(Nil)))
}

/// Starts the fake service on `port`.
pub fn start(
  port: Int,
  slow_requests: Subject(Subject(Nil)),
) -> Result(ServerHandle, String) {
  server.new()
  |> server.context(EmptyContext)
  |> server.services(FakeServices(slow_requests:))
  |> server.router(fake_router())
  |> server.listen_with_handle(port)
  |> result.map_error(string.inspect)
}

fn fake_router() -> Router(EmptyContext, FakeServices) {
  router()
  |> route(
    method: Get,
    path: "/v1/forecasts/:city",
    controller: forecast,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/v1/forecasts/:city/hourly",
    controller: hourly,
    middleware: [],
  )
  |> route(
    method: Post,
    path: "/v1/watches",
    controller: create_watch,
    middleware: [],
  )
}

fn forecast(
  request: Request,
  _context: EmptyContext,
  services: FakeServices,
) -> Response {
  case require_string(request, "city") {
    Ok("oslo") ->
      json_response(200, "{\"city\":\"oslo\",\"high\":4,\"low\":-2}")
    Ok("lima") ->
      json_response(200, "{\"city\":\"lima\",\"high\":\"warm\",\"low\":18}")
    Ok("broken") -> text_response(500, "The database is down")
    Ok("slow") -> answer_when_released(services.slow_requests)
    Ok(city) -> unknown_city(city)
    Error(problem) -> text_response(400, error.message(problem))
  }
}

// Tells the test that the request came, and waits until the test sends
// a message, at most 1 second.
fn answer_when_released(slow_requests: Subject(Subject(Nil))) -> Response {
  let release = process.new_subject()
  process.send(slow_requests, release)
  case process.receive(release, 1000) {
    Ok(Nil) -> json_response(200, "{\"city\":\"slow\",\"high\":1,\"low\":0}")
    Error(Nil) -> text_response(503, "Nobody released the request")
  }
}

fn hourly(
  request: Request,
  _context: EmptyContext,
  _services: FakeServices,
) -> Response {
  case require_string(request, "city") {
    Ok("oslo") ->
      [<<"06:00 3C\n">>, <<"07:00 4C\n">>, <<"08:00 5C\n">>]
      |> yielder.from_list
      |> stream_response(200, _, "text/plain")
    Ok(city) -> unknown_city(city)
    Error(problem) -> text_response(400, error.message(problem))
  }
}

fn create_watch(
  request: Request,
  _context: EmptyContext,
  _services: FakeServices,
) -> Response {
  let city_decoder = decode.field("city", decode.string, decode.success)
  case request.body_as_string(request) {
    Ok(body) -> watch_response(json.parse(body, city_decoder))
    Error(Nil) -> text_response(400, "The body is not text")
  }
}

fn watch_response(city: Result(String, json.DecodeError)) -> Response {
  case city {
    Ok(city) ->
      json.object([
        #("id", json.string("watch-" <> city)),
        #("city", json.string(city)),
      ])
      |> json.to_string
      |> json_response(201, _)
    Error(problem) -> text_response(400, string.inspect(problem))
  }
}

fn unknown_city(city: String) -> Response {
  json_response(404, "{\"error\":\"unknown city " <> city <> "\"}")
}
