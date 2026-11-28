//// Templates guide: a test of the format a request asks for
////
//// detect_format is from test/snippets/multiple_formats_guide_tasks.gleam.

import dream/http/header.{type Header, Header}
import dream/http/request.{type Request, Get, Http, Http1, Request}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/option
import snippets/multiple_formats_guide_tasks.{detect_format}

// A request for /tasks/:id, with the id segment as the router gives it
fn task_request(id_segment: String, headers: List(Header)) -> Request {
  Request(
    method: Get,
    protocol: Http,
    version: Http1,
    path: "/tasks/" <> id_segment,
    query: "",
    params: [#("id", id_segment)],
    host: option.None,
    port: option.None,
    remote_address: option.None,
    body: request.Text(""),
    headers: headers,
    cookies: [],
    content_type: option.None,
    content_length: option.None,
  )
}

pub fn tests() -> TestSuite {
  describe("detect_format", [
    it("takes the format from the extension of the id", fn() {
      // Arrange
      let request = task_request("1.csv", [])

      // Act
      let format = detect_format(request)

      // Assert
      format
      |> should
      |> be_equal("csv")
      |> or_fail_with("/tasks/1.csv should ask for csv")
    }),
    it("answers htmx for an HTMX request with no extension", fn() {
      // Arrange
      let request = task_request("1", [Header("HX-Request", "true")])

      // Act
      let format = detect_format(request)

      // Assert
      format
      |> should
      |> be_equal("htmx")
      |> or_fail_with("HX-Request: true should ask for htmx")
    }),
    it("falls back to json", fn() {
      // Arrange
      let request = task_request("1", [])

      // Act
      let format = detect_format(request)

      // Assert
      format
      |> should
      |> be_equal("json")
      |> or_fail_with("no extension and no header should give json")
    }),
  ])
}
