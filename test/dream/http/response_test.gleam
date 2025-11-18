import dream/http/header.{Header}
import dream/http/response.{
  Text, empty_response, html_response, json_response, redirect_response,
  text_response,
}
import dream/http/status
import gleam/option
import gleeunit/should

pub fn json_response_creates_response_with_correct_content_type_test() {
  // Arrange
  let body = "{\"message\": \"Hello\"}"

  // Act
  let result = json_response(status.ok, body)

  // Assert
  result.status |> should.equal(200)
  result.content_type
  |> should.equal(option.Some("application/json; charset=utf-8"))

  case result.body {
    Text(text) -> text |> should.equal(body)
    _ -> should.fail()
  }
}

pub fn html_response_creates_response_with_correct_content_type_test() {
  // Arrange
  let body = "<h1>Hello</h1>"

  // Act
  let result = html_response(status.ok, body)

  // Assert
  result.status |> should.equal(200)
  result.content_type |> should.equal(option.Some("text/html; charset=utf-8"))
}

pub fn text_response_creates_response_with_correct_content_type_test() {
  // Arrange
  let body = "Hello"

  // Act
  let result = text_response(status.ok, body)

  // Assert
  result.status |> should.equal(200)
  result.content_type |> should.equal(option.Some("text/plain; charset=utf-8"))
}

pub fn redirect_response_creates_response_with_location_header_test() {
  // Arrange
  let location = "/users/123"

  // Act
  let result = redirect_response(status.found, location)

  // Assert
  result.status |> should.equal(302)

  case result.headers {
    [Header("Location", loc)] -> loc |> should.equal(location)
    _ -> should.fail()
  }
}

pub fn empty_response_creates_response_with_empty_body_test() {
  // Arrange & Act
  let result = empty_response(status.no_content)

  // Assert
  result.status |> should.equal(204)

  case result.body {
    Text("") -> Nil
    _ -> should.fail()
  }
}
