//// Parser for the text of a `.env` file.
////
//// This module is internal to `dream_config`. Use `dream_config/loader`.
////
//// The format is the one that the `dot_env` package reads:
////
//// - Each variable is `NAME=VALUE` on its own line. An `export ` before the
////   name is allowed and has no effect. The name is trimmed and changed to
////   upper case.
//// - A value with no quote ends at the end of the line or at a `#`, and is
////   trimmed.
//// - A value in double quotes (`"`), single quotes (`'`) or backticks (`` ` ``)
////   can hold `#` and line breaks. A backslash before the quote character
////   puts that character in the value. In double quotes, `\n` is a line
////   break. After the closing quote, only spaces and a comment can follow on
////   the same line.
//// - A line that starts with `#` is a comment. Empty lines are skipped.
//// - Windows line endings (`\r\n`) are read as `\n`.

import gleam/list
import gleam/result
import gleam/string

/// One variable from a `.env` file.
pub type Variable {
  Variable(name: String, value: String)
}

/// Why the text is not a valid `.env` file.
///
/// `line` is the line number (from 1) where the problem is. For a quote that
/// is not closed, it is the line of the opening quote.
pub type ParseError {
  ParseError(line: Int, reason: String)
}

type Quote {
  Quote(character: String, name: String)
}

/// Parse the text of a `.env` file into its variables, in file order.
///
/// Returns `Error(ParseError)` for the first line that is not valid: a line
/// with no `=`, an empty name, a quote that is not closed, or text after a
/// closing quote.
pub fn parse(text: String) -> Result(List(Variable), ParseError) {
  text
  |> string.replace("\r\n", "\n")
  |> string.to_graphemes
  |> parse_lines(1, [])
}

fn parse_lines(
  characters: List(String),
  line: Int,
  variables: List(Variable),
) -> Result(List(Variable), ParseError) {
  case characters {
    [] -> Ok(list.reverse(variables))
    ["\n", ..rest] -> parse_lines(rest, line + 1, variables)
    [" ", ..rest] | ["\t", ..rest] -> parse_lines(rest, line, variables)
    ["#", ..rest] -> parse_lines(skip_comment(rest), line, variables)
    ["e", "x", "p", "o", "r", "t", " ", ..rest] ->
      parse_lines(rest, line, variables)
    _ -> parse_variable(characters, line, variables)
  }
}

fn parse_variable(
  characters: List(String),
  line: Int,
  variables: List(Variable),
) -> Result(List(Variable), ParseError) {
  use #(name, after_name) <- result.try(parse_name(characters, line, []))
  use #(value, rest, next_line) <- result.try(parse_value(after_name, line))
  let variable = Variable(name: string.uppercase(name), value: value)
  parse_lines(rest, next_line, [variable, ..variables])
}

fn parse_name(
  characters: List(String),
  line: Int,
  name: List(String),
) -> Result(#(String, List(String)), ParseError) {
  case characters {
    ["=", ..rest] -> check_name(join(name) |> string.trim, rest, line)
    [] | ["\n", ..] -> Error(ParseError(line, "expected NAME=VALUE"))
    [character, ..rest] -> parse_name(rest, line, [character, ..name])
  }
}

fn check_name(
  name: String,
  rest: List(String),
  line: Int,
) -> Result(#(String, List(String)), ParseError) {
  case name {
    "" -> Error(ParseError(line, "expected NAME=VALUE"))
    _ -> Ok(#(name, rest))
  }
}

/// Returns the value, the characters after it (from the end of its line) and
/// the line number of that end of line.
fn parse_value(
  characters: List(String),
  line: Int,
) -> Result(#(String, List(String), Int), ParseError) {
  case characters {
    ["\"", ..rest] ->
      parse_quoted(rest, Quote("\"", "double quote"), line, line, [])
    ["'", ..rest] ->
      parse_quoted(rest, Quote("'", "single quote"), line, line, [])
    ["`", ..rest] -> parse_quoted(rest, Quote("`", "backtick"), line, line, [])
    _ -> Ok(parse_unquoted(characters, line, []))
  }
}

fn parse_unquoted(
  characters: List(String),
  line: Int,
  value: List(String),
) -> #(String, List(String), Int) {
  case characters {
    [] | ["\n", ..] -> #(join(value) |> string.trim, characters, line)
    ["#", ..rest] -> #(join(value) |> string.trim, skip_comment(rest), line)
    [character, ..rest] -> parse_unquoted(rest, line, [character, ..value])
  }
}

fn parse_quoted(
  characters: List(String),
  quote: Quote,
  opening_line: Int,
  line: Int,
  value: List(String),
) -> Result(#(String, List(String), Int), ParseError) {
  let quote_character = quote.character
  case characters {
    [] ->
      Error(ParseError(opening_line, "the " <> quote.name <> " is not closed"))
    ["\\", character, ..rest] if character == quote_character ->
      parse_quoted(rest, quote, opening_line, line, [character, ..value])
    ["\\", "n", ..rest] if quote_character == "\"" ->
      parse_quoted(rest, quote, opening_line, line, ["\n", ..value])
    ["\n", ..rest] ->
      parse_quoted(rest, quote, opening_line, line + 1, ["\n", ..value])
    [character, ..rest] if character == quote_character ->
      finish_quoted(rest, quote, line, join(value))
    [character, ..rest] ->
      parse_quoted(rest, quote, opening_line, line, [character, ..value])
  }
}

fn finish_quoted(
  characters: List(String),
  quote: Quote,
  line: Int,
  value: String,
) -> Result(#(String, List(String), Int), ParseError) {
  use rest <- result.try(skip_to_line_end(characters, quote, line))
  Ok(#(value, rest, line))
}

fn skip_to_line_end(
  characters: List(String),
  quote: Quote,
  line: Int,
) -> Result(List(String), ParseError) {
  case characters {
    [] | ["\n", ..] -> Ok(characters)
    [" ", ..rest] | ["\t", ..rest] -> skip_to_line_end(rest, quote, line)
    ["#", ..rest] -> Ok(skip_comment(rest))
    _ ->
      Error(ParseError(line, "unexpected text after the closing " <> quote.name))
  }
}

/// Returns the characters from the end of the comment's line.
fn skip_comment(characters: List(String)) -> List(String) {
  case characters {
    [] | ["\n", ..] -> characters
    [_, ..rest] -> skip_comment(rest)
  }
}

fn join(reversed_characters: List(String)) -> String {
  reversed_characters |> list.reverse |> string.concat
}
