import dream/core/http/response
import dream/core/http/status
import dream/core/http/transaction
import gleam/option
import gleeunit/should

pub fn json_response_creates_response_with_correct_content_type_test() {
  // Arrange
  let body = "{\"message\": \"Hello\"}"

  // Act
  let result = response.json_response(status.ok, body)

  // Assert
  result.status |> should.equal(200)
  result.content_type |> should.equal(option.Some("application/json; charset=utf-8"))
  
  case result.body {
    transaction.Text(text) -> text |> should.equal(body)
    _ -> should.fail()
  }
}

pub fn html_response_creates_response_with_correct_content_type_test() {
  // Arrange
  let body = "<h1>Hello</h1>"

  // Act
  let result = response.html_response(status.ok, body)

  // Assert
  result.status |> should.equal(200)
  result.content_type |> should.equal(option.Some("text/html; charset=utf-8"))
}

pub fn text_response_creates_response_with_correct_content_type_test() {
  // Arrange
  let body = "Hello"

  // Act
  let result = response.text_response(status.ok, body)

  // Assert
  result.status |> should.equal(200)
  result.content_type |> should.equal(option.Some("text/plain; charset=utf-8"))
}

pub fn redirect_response_creates_response_with_location_header_test() {
  // Arrange
  let location = "/users/123"

  // Act
  let result = response.redirect_response(status.found, location)

  // Assert
  result.status |> should.equal(302)
  
  case result.headers {
    [transaction.Header("Location", loc)] -> loc |> should.equal(location)
    _ -> should.fail()
  }
}

pub fn empty_response_creates_response_with_empty_body_test() {
  // Arrange & Act
  let result = response.empty_response(status.no_content)

  // Assert
  result.status |> should.equal(204)
  
  case result.body {
    transaction.Text("") -> Nil
    _ -> should.fail()
  }
}

