import dream_opensearch/query
import gleeunit
import gleeunit/should
import gleam/string

pub fn main() {
  gleeunit.main()
}

pub fn match_all_creates_valid_query_test() {
  // Arrange
  // (no setup needed)
  
  // Act
  let query_json = query.match_all()
  
  // Assert
  query_json |> string.contains("match_all") |> should.equal(True)
}

pub fn term_creates_valid_query_test() {
  // Arrange
  let field = "status"
  let value = "published"
  
  // Act
  let query_json = query.term(field, value)
  
  // Assert
  query_json |> string.contains("term") |> should.equal(True)
  query_json |> string.contains(field) |> should.equal(True)
  query_json |> string.contains(value) |> should.equal(True)
}

pub fn match_creates_valid_query_test() {
  // Arrange
  let field = "title"
  let value = "hello world"
  
  // Act
  let query_json = query.match(field, value)
  
  // Assert
  query_json |> string.contains("match") |> should.equal(True)
  query_json |> string.contains(field) |> should.equal(True)
  query_json |> string.contains(value) |> should.equal(True)
}

