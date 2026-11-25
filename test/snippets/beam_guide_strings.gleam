//// BEAM guide: build a string with string_tree

import gleam/list
import gleam/string_tree

/// Wrong: puts each line in front of the text so far. Each step copies
/// all of the text so far.
pub fn report_by_prepending(lines: List(String)) -> String {
  list.fold(lines, "", fn(text, line) { line <> "\n" <> text })
}

/// Adds each line to the end of the text so far. The runtime can grow
/// the text in place when nothing else holds the old text.
pub fn report_by_appending(lines: List(String)) -> String {
  list.fold(lines, "", fn(text, line) { text <> line <> "\n" })
}

/// Fix: collect the pieces in a string tree, and join them one time at
/// the end
pub fn report(lines: List(String)) -> String {
  list.fold(lines, string_tree.new(), fn(tree, line) {
    tree
    |> string_tree.append(line)
    |> string_tree.append("\n")
  })
  |> string_tree.to_string
}
