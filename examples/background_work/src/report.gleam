//// The work of a job in this example: a short summary of a text. In your
//// app, this is the slow work, such as a PDF or a large export.

import gleam/int
import gleam/list
import gleam/string

/// The number of words and lines in `text`
pub fn summarise(text: String) -> String {
  let lines = string.split(text, "\n")
  let words =
    lines
    |> list.flat_map(string.split(_, " "))
    |> list.filter(fn(word) { word != "" })
  "words: "
  <> int.to_string(list.length(words))
  <> ", lines: "
  <> int.to_string(list.length(lines))
}
