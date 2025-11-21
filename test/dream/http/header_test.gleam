import dream/http/header.{Header, get_header, set_header}
import gleam/list
import gleam/option
import gleeunit/should

pub fn get_header_with_existing_header_returns_value_test() {
  let headers = [
    Header("Content-Type", "application/json"),
    Header("Authorization", "Bearer token"),
  ]

  let result = get_header(headers, "Content-Type")

  case result {
    option.Some(value) -> value |> should.equal("application/json")
    option.None -> should.fail()
  }
}

pub fn set_header_with_new_header_adds_header_test() {
  let headers = []
  let result = set_header(headers, "X-Custom", "value")

  list.length(result) |> should.equal(1)
}
