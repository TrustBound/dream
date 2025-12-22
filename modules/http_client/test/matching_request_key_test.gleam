import dream_http_client/matching
import dream_http_client/recording
import gleam/http
import gleam/option
import gleeunit/should

pub fn request_key_with_headers_enabled_sorts_headers_by_name_test() {
  let key =
    matching.request_key(method: True, url: True, headers: True, body: False)

  let req1 =
    recording.RecordedRequest(
      method: http.Get,
      scheme: http.Http,
      host: "localhost",
      port: option.None,
      path: "/text",
      query: option.None,
      headers: [#("b", "2"), #("a", "1")],
      body: "",
    )

  let req2 =
    recording.RecordedRequest(
      method: http.Get,
      scheme: http.Http,
      host: "localhost",
      port: option.None,
      path: "/text",
      query: option.None,
      headers: [#("a", "1"), #("b", "2")],
      body: "",
    )

  key(req1) |> should.equal(key(req2))
}

pub fn request_key_normalizes_http_other_methods_to_uppercase_test() {
  let key =
    matching.request_key(method: True, url: True, headers: False, body: False)

  let req_get =
    recording.RecordedRequest(
      method: http.Get,
      scheme: http.Http,
      host: "localhost",
      port: option.None,
      path: "/text",
      query: option.None,
      headers: [],
      body: "",
    )

  let req_other =
    recording.RecordedRequest(
      method: http.Other("get"),
      scheme: http.Http,
      host: "localhost",
      port: option.None,
      path: "/text",
      query: option.None,
      headers: [],
      body: "",
    )

  key(req_get) |> should.equal(key(req_other))
}
