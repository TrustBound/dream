//// Tests for the `.env` parser in `dream_config/internal/dotenv`.

import dream_config/internal/dotenv.{ParseError, Variable}
import gleeunit/should

pub fn parse_reads_name_and_value_pairs_test() {
  // Act
  let result = dotenv.parse("FIRST=one\nSECOND = two \n")

  // Assert
  result
  |> should.equal(Ok([Variable("FIRST", "one"), Variable("SECOND", "two")]))
}

pub fn parse_changes_names_to_upper_case_test() {
  // Act
  let result = dotenv.parse("database_url=postgres://localhost/app")

  // Assert
  result
  |> should.equal(Ok([Variable("DATABASE_URL", "postgres://localhost/app")]))
}

pub fn parse_skips_comments_empty_lines_and_export_test() {
  // Act
  let result =
    dotenv.parse("# a comment\n\n  \nexport NAME=value # trailing comment\n")

  // Assert
  result |> should.equal(Ok([Variable("NAME", "value")]))
}

pub fn parse_reads_an_empty_value_test() {
  // Act
  let result = dotenv.parse("EMPTY=\nCOMMENT_ONLY=# nothing\n")

  // Assert
  result
  |> should.equal(Ok([Variable("EMPTY", ""), Variable("COMMENT_ONLY", "")]))
}

pub fn parse_reads_quoted_values_test() {
  // Act
  let result =
    dotenv.parse(
      "DOUBLE=\"a # b \\\" c\\nd\"\nSINGLE=' x \\' y '\nBACKTICK=`p \\` q`\n",
    )

  // Assert
  result
  |> should.equal(
    Ok([
      Variable("DOUBLE", "a # b \" c\nd"),
      Variable("SINGLE", " x ' y "),
      Variable("BACKTICK", "p ` q"),
    ]),
  )
}

pub fn parse_reads_a_quoted_value_over_several_lines_test() {
  // Act
  let result = dotenv.parse("KEY=\"line one\nline two\"\nNEXT=x\n")

  // Assert
  result
  |> should.equal(
    Ok([Variable("KEY", "line one\nline two"), Variable("NEXT", "x")]),
  )
}

pub fn parse_counts_lines_inside_a_quoted_value_test() {
  // Act
  let result = dotenv.parse("KEY=\"line one\nline two\"\nBROKEN\n")

  // Assert
  result |> should.equal(Error(ParseError(3, "expected NAME=VALUE")))
}

pub fn parse_reads_windows_line_endings_test() {
  // Act
  let result = dotenv.parse("FIRST=one\r\nSECOND=two\r\n")

  // Assert
  result
  |> should.equal(Ok([Variable("FIRST", "one"), Variable("SECOND", "two")]))
}

pub fn parse_with_empty_name_returns_error_test() {
  // Act
  let result = dotenv.parse("OK=1\n=value\n")

  // Assert
  result |> should.equal(Error(ParseError(2, "expected NAME=VALUE")))
}

pub fn parse_with_unclosed_single_quote_gives_opening_line_test() {
  // Act
  let result = dotenv.parse("OK=1\nKEY='open\nmore\n")

  // Assert
  result
  |> should.equal(Error(ParseError(2, "the single quote is not closed")))
}

pub fn parse_with_text_after_closing_quote_returns_error_test() {
  // Act
  let result = dotenv.parse("KEY=\"value\" extra\n")

  // Assert
  result
  |> should.equal(
    Error(ParseError(1, "unexpected text after the closing double quote")),
  )
}
