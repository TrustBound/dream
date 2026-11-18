//// Black-box tests for `dream_opensearch/query`.
////
//// Every builder returns a JSON string, so each test pins the whole string.

import dream_opensearch/query
import gleam/string
import gleeunit/should

// ============================================================================
// match_all
// ============================================================================

pub fn match_all_returns_match_all_query_json_test() {
  // Arrange
  // (no input)

  // Act
  let query_json = query.match_all()

  // Assert
  query_json |> should.equal("{\"query\":{\"match_all\":{}}}")
}

// ============================================================================
// term
// ============================================================================

pub fn term_returns_term_query_json_test() {
  // Arrange
  let field = "status"
  let value = "published"

  // Act
  let query_json = query.term(field, value)

  // Assert
  query_json
  |> should.equal("{\"query\":{\"term\":{\"status\":\"published\"}}}")
}

pub fn term_with_empty_field_and_value_returns_empty_keys_test() {
  // Arrange
  let field = ""
  let value = ""

  // Act
  let query_json = query.term(field, value)

  // Assert
  query_json |> should.equal("{\"query\":{\"term\":{\"\":\"\"}}}")
}

pub fn term_with_quote_and_backslash_in_value_escapes_them_test() {
  // Arrange
  let field = "name"
  let value = "say \"hi\" \\ bye"

  // Act
  let query_json = query.term(field, value)

  // Assert
  query_json
  |> should.equal(
    "{\"query\":{\"term\":{\"name\":\"say \\\"hi\\\" \\\\ bye\"}}}",
  )
}

pub fn term_with_quote_in_field_escapes_it_test() {
  // Arrange
  let field = "a\"b"
  let value = "x"

  // Act
  let query_json = query.term(field, value)

  // Assert
  query_json |> should.equal("{\"query\":{\"term\":{\"a\\\"b\":\"x\"}}}")
}

pub fn term_with_newline_tab_and_control_character_escapes_them_test() {
  // Arrange
  let field = "notes"
  let value = "line1\nline2\ttab\u{0001}"

  // Act
  let query_json = query.term(field, value)

  // Assert
  query_json
  |> should.equal(
    "{\"query\":{\"term\":{\"notes\":\"line1\\nline2\\ttab\\u0001\"}}}",
  )
}

pub fn term_with_unicode_value_keeps_it_test() {
  // Arrange
  let field = "名前"
  let value = "zoë 日本 🎉"

  // Act
  let query_json = query.term(field, value)

  // Assert
  query_json |> should.equal("{\"query\":{\"term\":{\"名前\":\"zoë 日本 🎉\"}}}")
}

pub fn term_with_json_like_value_keeps_it_as_a_string_test() {
  // Arrange
  let field = "status"
  let value = "\"},\"match_all\":{\""

  // Act
  let query_json = query.term(field, value)

  // Assert
  query_json
  |> should.equal(
    "{\"query\":{\"term\":{\"status\":\"\\\"},\\\"match_all\\\":{\\\"\"}}}",
  )
}

pub fn term_with_very_long_value_keeps_whole_value_test() {
  // Arrange
  let value = string.repeat("x", 100_000)

  // Act
  let query_json = query.term("f", value)

  // Assert
  query_json
  |> should.equal(
    "{\"query\":{\"term\":{\"f\":\"" <> string.repeat("x", 100_000) <> "\"}}}",
  )
}

// ============================================================================
// range
// ============================================================================

pub fn range_returns_range_query_json_test() {
  // Arrange
  let field = "price"
  let gte = "10"
  let lte = "100"

  // Act
  let query_json = query.range(field, gte, lte)

  // Assert
  query_json
  |> should.equal(
    "{\"query\":{\"range\":{\"price\":{\"gte\":\"10\",\"lte\":\"100\"}}}}",
  )
}

pub fn range_with_date_bounds_returns_them_as_strings_test() {
  // Arrange
  let field = "created_at"
  let gte = "2026-01-01T00:00:00Z"
  let lte = "now"

  // Act
  let query_json = query.range(field, gte, lte)

  // Assert
  query_json
  |> should.equal(
    "{\"query\":{\"range\":{\"created_at\":{\"gte\":\"2026-01-01T00:00:00Z\",\"lte\":\"now\"}}}}",
  )
}

pub fn range_with_empty_bounds_returns_empty_strings_test() {
  // Arrange
  let field = "age"
  let gte = ""
  let lte = ""

  // Act
  let query_json = query.range(field, gte, lte)

  // Assert
  query_json
  |> should.equal(
    "{\"query\":{\"range\":{\"age\":{\"gte\":\"\",\"lte\":\"\"}}}}",
  )
}

pub fn range_with_quotes_backslash_and_newline_escapes_them_test() {
  // Arrange
  let field = "f\"x"
  let gte = "a\\b"
  let lte = "c\nd"

  // Act
  let query_json = query.range(field, gte, lte)

  // Assert
  query_json
  |> should.equal(
    "{\"query\":{\"range\":{\"f\\\"x\":{\"gte\":\"a\\\\b\",\"lte\":\"c\\nd\"}}}}",
  )
}

pub fn range_with_unicode_bounds_keeps_them_test() {
  // Arrange
  let field = "名前"
  let gte = "α"
  let lte = "ω🎉"

  // Act
  let query_json = query.range(field, gte, lte)

  // Assert
  query_json
  |> should.equal(
    "{\"query\":{\"range\":{\"名前\":{\"gte\":\"α\",\"lte\":\"ω🎉\"}}}}",
  )
}

// ============================================================================
// match
// ============================================================================

pub fn match_returns_match_query_json_test() {
  // Arrange
  let field = "title"
  let text = "hello world"

  // Act
  let query_json = query.match(field, text)

  // Assert
  query_json
  |> should.equal("{\"query\":{\"match\":{\"title\":\"hello world\"}}}")
}

pub fn match_with_empty_field_and_text_returns_empty_keys_test() {
  // Arrange
  let field = ""
  let text = ""

  // Act
  let query_json = query.match(field, text)

  // Assert
  query_json |> should.equal("{\"query\":{\"match\":{\"\":\"\"}}}")
}

pub fn match_with_quote_backslash_and_newline_escapes_them_test() {
  // Arrange
  let field = "body"
  let text = "he said \"no\"\\\nthen left"

  // Act
  let query_json = query.match(field, text)

  // Assert
  query_json
  |> should.equal(
    "{\"query\":{\"match\":{\"body\":\"he said \\\"no\\\"\\\\\\nthen left\"}}}",
  )
}

pub fn match_with_unicode_text_keeps_it_test() {
  // Arrange
  let field = "title"
  let text = "café 東京 🎉"

  // Act
  let query_json = query.match(field, text)

  // Assert
  query_json
  |> should.equal("{\"query\":{\"match\":{\"title\":\"café 東京 🎉\"}}}")
}
