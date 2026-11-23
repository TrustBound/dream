//// Streaming guide: a test of an upload controller with a broken stream
////
//// upload_stream is from test/snippets/streaming_guide_ingress.gleam. A
//// stream body is a Yielder of Result(BitArray, BodyReadError), so a test
//// can build one that breaks in the middle.

import dream/http/request.{
  type BodyReadError, type Request, Http, Http1, MalformedBody, Post, Request,
  Stream,
}
import dream/http/response.{Text}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/option
import gleam/yielder
import snippets/streaming_guide_ingress

fn upload(chunks: List(Result(BitArray, BodyReadError))) -> Request {
  Request(
    method: Post,
    protocol: Http,
    version: Http1,
    path: "/upload_stream",
    query: "",
    params: [],
    host: option.None,
    port: option.None,
    remote_address: option.None,
    body: Stream(yielder.from_list(chunks)),
    headers: [],
    cookies: [],
    content_type: option.None,
    content_length: option.None,
  )
}

pub fn tests() -> TestSuite {
  describe("upload_stream", [
    it("counts the bytes of every chunk", fn() {
      // Arrange
      let request = upload([Ok(<<"hello ":utf8>>), Ok(<<"world":utf8>>)])

      // Act
      let response = streaming_guide_ingress.upload_stream(request, Nil, Nil)

      // Assert
      response.body
      |> should
      |> be_equal(Text("Uploaded 11 bytes successfully"))
      |> or_fail_with("two chunks of 6 and 5 bytes should give 11")
    }),
    it("answers 400 when the stream breaks", fn() {
      // Arrange
      let request = upload([Ok(<<"hello ":utf8>>), Error(MalformedBody)])

      // Act
      let response = streaming_guide_ingress.upload_stream(request, Nil, Nil)

      // Assert
      response.status
      |> should
      |> be_equal(400)
      |> or_fail_with("a broken stream should answer 400")
    }),
  ])
}
