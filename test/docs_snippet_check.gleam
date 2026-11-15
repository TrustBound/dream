//// Checks that every Gleam code block in the docs is backed by tested code.
////
//// The rule is in `docs/contributing/contributing.md`, in "Code Blocks in
//// READMEs and Guides". In short, each ```` ```gleam ```` block in a
//// Markdown doc, and each one in a `///` or `////` doc comment in `src/`,
//// has a heading directly above it that ends with the "tested snippet"
//// badge. The badge links to a file in this repository at the tag of the
//// version in `gleam.toml`, for example
//// `https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/name.gleam#L8-L10`.
//// The block is that whole file, or exactly that line range, byte for byte.
//// The tests compile and run the file, so the code in the docs is code
//// that works.
////
//// Run it from the repository root:
////
//// ```sh
//// gleam run -m docs_snippet_check
//// ```
////
//// It prints one line for each problem, as `file:line: reason`, sorted by
//// file and line, then a summary line. It stops with exit code 1 when it
//// finds a problem. It never uses the network: a badge link is changed to
//// a local path and the file is read from the working tree.
////
//// A fence with another language (or no language) must not hold Gleam
//// code, because then the check would not see it. A line in such a fence
//// is Gleam code when it is one of these forms, which no other language
//// that the docs use has (see `looks_like_gleam`):
////
//// - `import a/b` (a module path with a `/`) or `import a.{...}`
//// - `fn name(` or `pub fn name(`
//// - `pub type Name`, `pub opaque type Name` or `type Name` with no `=`
//// - `use x <- ...`
//// - `let assert ...`
//// - a pipe into a module function, such as `|> list.map(`
////
//// A ```` ```markdown ```` fence holds an example document. Its fences are
//// checked like the fences of any other document, and its other lines must
//// not look like Gleam code.
////
//// The module lives in `test/` so that it never ships in the Hex package.
//// The logic is in pure functions (`check_markdown`, `check_gleam_source`,
//// `sort_problems`, `describe_problem`). The `main` function only lists
//// and reads files and prints the result.

import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order.{type Order}
import gleam/result
import gleam/string
import simplifile

// ---------------------------------------------------------------------------
// Scope
// ---------------------------------------------------------------------------

/// The kind of file that a checked root holds.
pub type DocumentKind {
  /// A Markdown document (`.md`). Each fenced code block in it is checked.
  MarkdownDocument
  /// A Gleam source file (`.gleam`). Each fenced code block in its `///`
  /// and `////` doc comments is checked.
  GleamSource
}

/// A file, or a directory that is walked for files of one kind.
pub type CheckedRoot {
  CheckedRoot(path: String, kind: DocumentKind)
}

/// The places that the check reads, relative to the repository root. This
/// is the one list to change to widen or narrow the check.
///
/// These are not checked, on purpose:
///
/// - `releases/` and `CHANGELOG.md`: release notes show the code of older
///   versions, such as the "before" code in the 3.0.0 migration guide.
/// - `modules/`: each module gets the rule in its own repository.
/// - `.cursor/`: it holds prompts for coding agents, not docs.
/// - `research/`: it holds old notes.
/// - `build/` and dependency folders: see `skipped_directory_names`.
const checked_roots = [
  CheckedRoot("README.md", MarkdownDocument),
  CheckedRoot("SECURITY.md", MarkdownDocument),
  CheckedRoot("docs", MarkdownDocument),
  CheckedRoot("examples", MarkdownDocument),
  CheckedRoot("src", GleamSource),
]

/// Directory names that are never walked inside a checked root. They hold
/// build output and downloaded dependencies (for example
/// `examples/tasks/deps/` and `examples/simple/build/packages/`), whose
/// docs belong to other projects.
const skipped_directory_names = ["build", "deps", "_build", "node_modules"]

/// The file that holds the version that badge links must use as their tag.
const gleam_toml_path = "gleam.toml"

// ---------------------------------------------------------------------------
// The badge
// ---------------------------------------------------------------------------

/// The start of every badge link: a file in the dream GitHub repository.
const repository_blob_prefix = "https://github.com/TrustBound/dream/blob/"

/// The text between the start of a badge and its link address.
const badge_start = " <a href=\""

/// The exact text after the link address of a badge, to the end of the
/// heading.
const badge_end = "\"><img align=\"right\" alt=\"Tested snippet\" src=\"https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square\"></a>"

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// One line of a document, with its 1-based line number in the file.
pub type Line {
  Line(number: Int, text: String)
}

/// What the checks need from the outside.
///
/// `version` is the version in `gleam.toml`. `read_source` reads a file by
/// its path relative to the repository root. `main` gives it
/// `simplifile.read`; the tests give it a lookup in a list.
pub type CheckContext {
  CheckContext(
    version: String,
    read_source: fn(String) -> Result(String, simplifile.FileError),
  )
}

/// Why a code block fails the check.
pub type Reason {
  /// A Gleam block has no heading with the badge directly above it.
  MissingBadgeHeading
  /// A Gleam block uses the old `🧪 Tested source` line next to it.
  OldTestedSourceLine
  /// The heading has a badge, but not in the exact format.
  MalformedBadge
  /// The badge links to another repository or host, or out of the
  /// repository.
  ForeignLink(url: String)
  /// The tag in the badge link is not the version in `gleam.toml`.
  WrongTag(found: String, expected: String)
  /// The linked file does not exist in this repository.
  MissingFile(path: String)
  /// The linked file exists but cannot be read.
  UnreadableFile(path: String, reason: simplifile.FileError)
  /// The line anchor is not `#L<n>` or `#L<start>-L<end>`.
  MalformedLineRange(anchor: String)
  /// The line range starts after it ends.
  ReversedLineRange(start: Int, end: Int)
  /// The line range ends after the last line of the file.
  LineRangePastEnd(end: Int, line_count: Int)
  /// The block is not the same as the linked file or range.
  /// `first_difference_line` is the line in the document where the first
  /// difference is.
  BlockDiffers(path: String, anchor: String, first_difference_line: Int)
  /// A fence with another language holds a line that looks like Gleam.
  /// `language` is the fence language, or an empty string for none.
  HiddenGleamCode(language: String)
  /// A fence has no closing fence.
  UnclosedFence
}

/// One problem: the file, the 1-based line, and why.
pub type Problem {
  Problem(file: String, line: Int, reason: Reason)
}

/// The result of checking one or more documents.
///
/// `blocks_checked` counts the Gleam code blocks that were checked.
pub type Report {
  Report(blocks_checked: Int, problems: List(Problem))
}

/// A link to a tested snippet, read from a badge.
///
/// `anchor` is the line anchor with its `#`, or an empty string when the
/// link names the whole file.
pub type SnippetLink {
  SnippetLink(tag: String, path: String, anchor: String)
}

/// The part of a file that a badge link names.
pub type LineSelection {
  WholeFile
  LineRange(start: Int, end: Int)
}

/// An error that stops the check before it can report.
pub type CheckError {
  /// A directory could not be listed.
  ListFailed(path: String, reason: simplifile.FileError)
  /// A document could not be read.
  ReadFailed(path: String, reason: simplifile.FileError)
  /// `gleam.toml` has no `version = "..."` line.
  VersionNotFound(path: String)
}

/// The opening line of a fenced code block.
type FenceOpener {
  FenceOpener(indent: Int, marker: String, length: Int, language: String)
}

/// A fenced code block. `content` has the fence indent removed.
/// `closing_line` is the line number of the closing fence, or the line
/// after the end of the document when there is none.
type FencedBlock {
  FencedBlock(
    opener: FenceOpener,
    opening_line: Int,
    content: List(Line),
    closing_line: Int,
    closed: Bool,
  )
}

/// Where the scan is: at the top level of a document, or inside an example
/// document in a `markdown` fence, where lines must not look like Gleam.
type ScanPlace {
  TopLevel
  InsideExample
}

/// The kind of a line in a Gleam source file.
type CommentKind {
  ItemComment
  ModuleComment
  NotDocComment
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

/// Checks the docs in the current directory, prints each problem and a
/// summary, and stops with exit code 1 if there is a problem or an error,
/// so that `make check-snippets`, the pre-commit hook and CI fail too.
pub fn main() -> Nil {
  case run_check() {
    Ok(#(report, file_count)) -> print_report(report, file_count)
    Error(error) -> stop_with_error(error)
  }
}

fn print_report(report: Report, file_count: Int) -> Nil {
  let problems = sort_problems(report.problems)
  list.each(problems, fn(problem) { io.println(describe_problem(problem)) })
  io.println(summary(report.blocks_checked, file_count, list.length(problems)))
  case problems {
    [] -> Nil
    _ -> halt(1)
  }
}

fn stop_with_error(error: CheckError) -> Nil {
  io.println_error("error: " <> describe_error(error))
  halt(1)
}

@external(erlang, "erlang", "halt")
fn halt(status: Int) -> Nil

fn run_check() -> Result(#(Report, Int), CheckError) {
  use gleam_toml <- result.try(read_document(gleam_toml_path))
  use version <- result.try(parse_version(gleam_toml))
  use files <- result.try(list_checked_files())
  let context = CheckContext(version:, read_source: simplifile.read)
  use reports <- result.try(
    list.try_map(files, fn(file) { check_file(file, context) }),
  )
  Ok(#(merge_reports(reports), list.length(files)))
}

fn read_document(path: String) -> Result(String, CheckError) {
  simplifile.read(path)
  |> result.map_error(fn(reason) { ReadFailed(path, reason) })
}

fn check_file(
  file: #(String, DocumentKind),
  context: CheckContext,
) -> Result(Report, CheckError) {
  let #(path, kind) = file
  use text <- result.map(read_document(path))
  case kind {
    MarkdownDocument -> check_markdown(path, text, context)
    GleamSource -> check_gleam_source(path, text, context)
  }
}

fn list_checked_files() -> Result(List(#(String, DocumentKind)), CheckError) {
  checked_roots
  |> list.try_map(list_root_files)
  |> result.map(list.flatten)
}

fn list_root_files(
  root: CheckedRoot,
) -> Result(List(#(String, DocumentKind)), CheckError) {
  case simplifile.is_directory(root.path) {
    Ok(True) -> walk_directory(root.path, root.kind)
    Ok(False) -> Ok([#(root.path, root.kind)])
    Error(reason) -> Error(ListFailed(root.path, reason))
  }
}

fn walk_directory(
  path: String,
  kind: DocumentKind,
) -> Result(List(#(String, DocumentKind)), CheckError) {
  use names <- result.try(
    simplifile.read_directory(path)
    |> result.map_error(fn(reason) { ListFailed(path, reason) }),
  )
  names
  |> list.filter(fn(name) { !list.contains(skipped_directory_names, name) })
  |> list.sort(string.compare)
  |> list.try_map(fn(name) { walk_entry(path <> "/" <> name, kind) })
  |> result.map(list.flatten)
}

fn walk_entry(
  path: String,
  kind: DocumentKind,
) -> Result(List(#(String, DocumentKind)), CheckError) {
  case simplifile.is_directory(path) {
    Ok(True) -> walk_directory(path, kind)
    Ok(False) -> Ok(keep_if_kind(path, kind))
    Error(reason) -> Error(ListFailed(path, reason))
  }
}

fn keep_if_kind(
  path: String,
  kind: DocumentKind,
) -> List(#(String, DocumentKind)) {
  case string.ends_with(path, file_extension(kind)) {
    True -> [#(path, kind)]
    False -> []
  }
}

fn file_extension(kind: DocumentKind) -> String {
  case kind {
    MarkdownDocument -> ".md"
    GleamSource -> ".gleam"
  }
}

/// Describes an error that stops the check, in one line.
pub fn describe_error(error: CheckError) -> String {
  case error {
    ListFailed(path:, reason:) ->
      "Cannot list " <> path <> ": " <> simplifile.describe_error(reason)
    ReadFailed(path:, reason:) ->
      "Cannot read " <> path <> ": " <> simplifile.describe_error(reason)
    VersionNotFound(path:) ->
      path <> " has no version = \"...\" line before its first [section]."
  }
}

/// Reads the package version from the text of `gleam.toml`: the
/// `version = "..."` line before the first `[section]`.
pub fn parse_version(gleam_toml: String) -> Result(String, CheckError) {
  gleam_toml
  |> string.split("\n")
  |> list.take_while(fn(line) { !string.starts_with(line, "[") })
  |> list.find_map(version_value)
  |> result.replace_error(VersionNotFound(gleam_toml_path))
}

fn version_value(line: String) -> Result(String, Nil) {
  use rest <- result.try(remove_prefix(string.trim(line), "version"))
  use rest <- result.try(remove_prefix(string.trim_start(rest), "="))
  use rest <- result.try(remove_prefix(string.trim(rest), "\""))
  use value <- result.try(remove_suffix(rest, "\""))
  case value == "" || string.contains(value, "\"") {
    True -> Error(Nil)
    False -> Ok(value)
  }
}

fn remove_prefix(text: String, prefix: String) -> Result(String, Nil) {
  case string.starts_with(text, prefix) {
    True -> Ok(string.drop_start(text, string.length(prefix)))
    False -> Error(Nil)
  }
}

fn remove_suffix(text: String, suffix: String) -> Result(String, Nil) {
  case string.ends_with(text, suffix) {
    True -> Ok(string.drop_end(text, string.length(suffix)))
    False -> Error(Nil)
  }
}

// ---------------------------------------------------------------------------
// Reports
// ---------------------------------------------------------------------------

/// Sorts problems by file, then by line. Problems on the same line keep
/// their order.
pub fn sort_problems(problems: List(Problem)) -> List(Problem) {
  list.sort(problems, compare_problems)
}

fn compare_problems(first: Problem, second: Problem) -> Order {
  order.break_tie(
    string.compare(first.file, second.file),
    int.compare(first.line, second.line),
  )
}

/// The last line of the output, for example
/// `412 blocks checked in 230 files, 0 problems`.
pub fn summary(blocks: Int, files: Int, problems: Int) -> String {
  int.to_string(blocks)
  <> " blocks checked in "
  <> int.to_string(files)
  <> " files, "
  <> int.to_string(problems)
  <> " problems"
}

/// Describes a problem in one line, as `file:line: reason`.
pub fn describe_problem(problem: Problem) -> String {
  problem.file
  <> ":"
  <> int.to_string(problem.line)
  <> ": "
  <> describe_reason(problem.reason)
}

/// Describes why a code block fails the check.
pub fn describe_reason(reason: Reason) -> String {
  case reason {
    MissingBadgeHeading ->
      "this gleam code block has no heading with the tested snippet badge directly above it (one blank line between is allowed)"
    OldTestedSourceLine ->
      "the old \"🧪 Tested source\" line is not used now; put the tested snippet badge at the end of the heading above the code block"
    MalformedBadge ->
      "the tested snippet badge is not in the exact format; copy it from docs/contributing/contributing.md"
    ForeignLink(url:) ->
      "the badge link "
      <> url
      <> " does not point at a file in https://github.com/TrustBound/dream"
    WrongTag(found:, expected:) ->
      "the badge link uses the tag "
      <> found
      <> ", but the version in gleam.toml is "
      <> expected
    MissingFile(path:) ->
      "the badge links to "
      <> path
      <> ", which is not a file in this repository"
    UnreadableFile(path:, reason:) ->
      "cannot read " <> path <> ": " <> simplifile.describe_error(reason)
    MalformedLineRange(anchor:) ->
      "the line anchor " <> anchor <> " is not #L<n> or #L<start>-L<end>"
    ReversedLineRange(start:, end:) ->
      "the line range starts at line "
      <> int.to_string(start)
      <> ", after its end at line "
      <> int.to_string(end)
    LineRangePastEnd(end:, line_count:) ->
      "the line range ends at line "
      <> int.to_string(end)
      <> ", but the file has "
      <> int.to_string(line_count)
      <> " lines"
    BlockDiffers(path:, anchor:, first_difference_line:) ->
      "the code block is not the same as "
      <> path
      <> anchor
      <> "; the first difference is at line "
      <> int.to_string(first_difference_line)
    HiddenGleamCode(language:) ->
      "this line looks like Gleam code in "
      <> describe_fence_language(language)
      <> "; put Gleam code in a gleam block with the tested snippet badge"
    UnclosedFence -> "this code fence has no closing fence"
  }
}

fn describe_fence_language(language: String) -> String {
  case language {
    "" -> "a code fence with no language"
    _ -> "a " <> language <> " code fence"
  }
}

fn merge_reports(reports: List(Report)) -> Report {
  list.fold(reports, Report(blocks_checked: 0, problems: []), add_report)
}

fn add_report(total: Report, report: Report) -> Report {
  Report(
    blocks_checked: total.blocks_checked + report.blocks_checked,
    problems: list.append(total.problems, report.problems),
  )
}

// ---------------------------------------------------------------------------
// Documents
// ---------------------------------------------------------------------------

/// Checks every fenced code block in a Markdown document.
///
/// `file` is the path of the document, used in each problem. `text` is its
/// content.
pub fn check_markdown(
  file: String,
  text: String,
  context: CheckContext,
) -> Report {
  scan(numbered_lines(text, 1), [], TopLevel, file, context, empty_report())
}

/// Checks every fenced code block in the `///` and `////` doc comments of
/// a Gleam source file.
///
/// Each run of doc comment lines of one kind is read as a Markdown
/// document: the comment prefix (`/// `, `//// `, or `///` and `////` on a
/// blank comment line) is removed, and each line keeps its line number in
/// the file. Leading spaces before the prefix are allowed, so indented doc
/// comments are checked too.
pub fn check_gleam_source(
  file: String,
  text: String,
  context: CheckContext,
) -> Report {
  numbered_lines(text, 1)
  |> list.map(classify_comment_line)
  |> list.chunk(by: fn(classified) { classified.0 })
  |> list.filter_map(comment_run)
  |> list.map(fn(run) { scan(run, [], TopLevel, file, context, empty_report()) })
  |> merge_reports
}

fn empty_report() -> Report {
  Report(blocks_checked: 0, problems: [])
}

fn numbered_lines(text: String, first_number: Int) -> List(Line) {
  text
  |> string.split("\n")
  |> list.index_map(fn(line_text, index) {
    Line(number: first_number + index, text: line_text)
  })
}

fn classify_comment_line(line: Line) -> #(CommentKind, Line) {
  let code = string.trim_start(line.text)
  let kind = comment_kind(code)
  let prefix_length = case kind {
    ModuleComment -> 4
    ItemComment -> 3
    NotDocComment -> 0
  }
  let comment_text = string.drop_start(code, prefix_length)
  let text = case string.starts_with(comment_text, " ") {
    True -> string.drop_start(comment_text, 1)
    False -> comment_text
  }
  #(kind, Line(..line, text:))
}

fn comment_kind(code: String) -> CommentKind {
  case code {
    "/////" <> _ -> NotDocComment
    "////" <> _ -> ModuleComment
    "///" <> _ -> ItemComment
    _ -> NotDocComment
  }
}

fn comment_run(run: List(#(CommentKind, Line))) -> Result(List(Line), Nil) {
  case run {
    [#(NotDocComment, _), ..] -> Error(Nil)
    [] -> Error(Nil)
    _ -> Ok(list.map(run, fn(classified) { classified.1 }))
  }
}

// ---------------------------------------------------------------------------
// Fences
// ---------------------------------------------------------------------------

/// Walks the lines of one document. `above` holds the lines before the
/// current one, nearest first, so that a block can find its heading.
fn scan(
  remaining: List(Line),
  above: List(Line),
  place: ScanPlace,
  file: String,
  context: CheckContext,
  report: Report,
) -> Report {
  case remaining {
    [] -> report
    [line, ..rest] -> scan_line(line, rest, above, place, file, context, report)
  }
}

fn scan_line(
  line: Line,
  rest: List(Line),
  above: List(Line),
  place: ScanPlace,
  file: String,
  context: CheckContext,
  report: Report,
) -> Report {
  case parse_fence_opener(line.text) {
    None -> {
      let report = add_report(report, check_prose_line(line, place, file))
      scan(rest, [line, ..above], place, file, context, report)
    }
    Some(opener) -> {
      let #(raw_content, closing, after) = split_fence(opener, rest, [])
      let block =
        FencedBlock(
          opener:,
          opening_line: line.number,
          content: list.map(raw_content, fn(content_line) {
            Line(
              ..content_line,
              text: remove_indent(content_line.text, opener.indent),
            )
          }),
          closing_line: closing_line_number(line, raw_content, closing),
          closed: option.is_some(closing),
        )
      let report =
        add_report(report, check_block(block, above, after, file, context))
      let above =
        list.flatten([
          option_to_list(closing),
          list.reverse(raw_content),
          [line],
          above,
        ])
      scan(after, above, place, file, context, report)
    }
  }
}

fn check_prose_line(line: Line, place: ScanPlace, file: String) -> Report {
  case place, looks_like_gleam(line.text) {
    InsideExample, True ->
      Report(blocks_checked: 0, problems: [
        Problem(file:, line: line.number, reason: HiddenGleamCode("markdown")),
      ])
    _, _ -> empty_report()
  }
}

fn closing_line_number(
  opening: Line,
  content: List(Line),
  closing: Option(Line),
) -> Int {
  case closing {
    Some(line) -> line.number
    None -> opening.number + list.length(content) + 1
  }
}

fn parse_fence_opener(text: String) -> Option(FenceOpener) {
  let trimmed = string.trim_start(text)
  let indent = string.length(text) - string.length(trimmed)
  let backticks = count_leading(trimmed, "`", 0)
  let tildes = count_leading(trimmed, "~", 0)
  case backticks >= 3, tildes >= 3 {
    True, _ -> fence_opener(trimmed, indent, "`", backticks)
    _, True -> fence_opener(trimmed, indent, "~", tildes)
    False, False -> None
  }
}

fn fence_opener(
  trimmed: String,
  indent: Int,
  marker: String,
  length: Int,
) -> Option(FenceOpener) {
  let info = string.trim(string.drop_start(trimmed, length))
  case marker == "`" && string.contains(info, "`") {
    True -> None
    False ->
      Some(FenceOpener(
        indent:,
        marker:,
        length:,
        language: string.lowercase(first_word(info)),
      ))
  }
}

fn first_word(text: String) -> String {
  case string.split_once(text, " ") {
    Ok(#(word, _)) -> word
    Error(Nil) -> text
  }
}

fn count_leading(text: String, character: String, count: Int) -> Int {
  case string.pop_grapheme(text) {
    Ok(#(first, rest)) if first == character ->
      count_leading(rest, character, count + 1)
    _ -> count
  }
}

fn is_fence_closer(text: String, opener: FenceOpener) -> Bool {
  let trimmed = string.trim(text)
  let run = count_leading(trimmed, opener.marker, 0)
  run >= opener.length && run == string.length(trimmed)
}

/// Splits the lines after an opening fence into the block content, the
/// closing fence (if any) and the lines after it.
fn split_fence(
  opener: FenceOpener,
  lines: List(Line),
  content: List(Line),
) -> #(List(Line), Option(Line), List(Line)) {
  case lines {
    [] -> #(list.reverse(content), None, [])
    [line, ..rest] -> split_fence_at(opener, line, rest, content)
  }
}

fn split_fence_at(
  opener: FenceOpener,
  line: Line,
  rest: List(Line),
  content: List(Line),
) -> #(List(Line), Option(Line), List(Line)) {
  case is_fence_closer(line.text, opener) {
    True -> #(list.reverse(content), Some(line), rest)
    False -> split_fence(opener, rest, [line, ..content])
  }
}

/// Removes up to `indent` leading spaces, as Markdown does for the lines
/// of an indented fence.
fn remove_indent(text: String, indent: Int) -> String {
  string.drop_start(text, int.min(indent, count_leading(text, " ", 0)))
}

// ---------------------------------------------------------------------------
// Blocks
// ---------------------------------------------------------------------------

fn check_block(
  block: FencedBlock,
  above: List(Line),
  after: List(Line),
  file: String,
  context: CheckContext,
) -> Report {
  let unclosed = case block.closed {
    True -> []
    False -> [Problem(file:, line: block.opening_line, reason: UnclosedFence)]
  }
  let report = case block.opener.language {
    "gleam" ->
      Report(
        blocks_checked: 1,
        problems: check_gleam_block(block, above, after, file, context),
      )
    "markdown" | "md" ->
      scan(block.content, [], InsideExample, file, context, empty_report())
    language ->
      Report(blocks_checked: 0, problems: hidden_gleam(block, language, file))
  }
  add_report(Report(blocks_checked: 0, problems: unclosed), report)
}

fn hidden_gleam(
  block: FencedBlock,
  language: String,
  file: String,
) -> List(Problem) {
  case list.find(block.content, fn(line) { looks_like_gleam(line.text) }) {
    Ok(line) -> [
      Problem(file:, line: line.number, reason: HiddenGleamCode(language)),
    ]
    Error(Nil) -> []
  }
}

fn check_gleam_block(
  block: FencedBlock,
  above: List(Line),
  after: List(Line),
  file: String,
  context: CheckContext,
) -> List(Problem) {
  let at_block = fn(reason) {
    Problem(file:, line: block.opening_line, reason:)
  }
  let old_line_below =
    old_tested_source_line(first_line_skipping_one_blank(after), file)
  let heading_problems = case first_line_skipping_one_blank(above) {
    None -> [at_block(MissingBadgeHeading)]
    Some(line) -> check_heading(line, block, file, context)
  }
  list.append(heading_problems, old_line_below)
}

/// The nearest line, or the line after one blank line. A second blank
/// line is returned as it is, so the block then has no heading.
fn first_line_skipping_one_blank(lines: List(Line)) -> Option(Line) {
  case lines {
    [] -> None
    [line, ..rest] -> line_or_next_after_blank(line, rest)
  }
}

fn line_or_next_after_blank(line: Line, rest: List(Line)) -> Option(Line) {
  case is_blank(line.text), rest {
    False, _ -> Some(line)
    True, [next, ..] -> Some(next)
    True, [] -> None
  }
}

fn is_blank(text: String) -> Bool {
  string.trim(text) == ""
}

fn is_old_tested_source_line(text: String) -> Bool {
  string.contains(text, "Tested source")
}

fn old_tested_source_line(line: Option(Line), file: String) -> List(Problem) {
  line
  |> option_to_list
  |> list.filter(fn(found) { is_old_tested_source_line(found.text) })
  |> list.map(fn(found) {
    Problem(file:, line: found.number, reason: OldTestedSourceLine)
  })
}

fn check_heading(
  heading: Line,
  block: FencedBlock,
  file: String,
  context: CheckContext,
) -> List(Problem) {
  case is_old_tested_source_line(heading.text) {
    True -> [Problem(file:, line: heading.number, reason: OldTestedSourceLine)]
    False ->
      heading_reasons(heading.text, block, context)
      |> list.map(fn(reason) {
        Problem(file:, line: block.opening_line, reason:)
      })
  }
}

fn heading_reasons(
  text: String,
  block: FencedBlock,
  context: CheckContext,
) -> List(Reason) {
  case parse_badge_heading(text) |> result.try(parse_snippet_link) {
    Ok(link) -> check_link(link, block, context)
    Error(reason) -> [reason]
  }
}

/// Reads a heading line that ends with the badge, and returns the link
/// address of the badge.
///
/// The line is a Markdown heading (`#` to `######`, a space and a title),
/// then `badge_start`, the address, and exactly `badge_end`.
pub fn parse_badge_heading(text: String) -> Result(String, Reason) {
  let trimmed = string.trim(text)
  let hashes = count_leading(trimmed, "#", 0)
  let is_heading =
    hashes >= 1
    && hashes <= 6
    && string.starts_with(string.drop_start(trimmed, hashes), " ")
  case is_heading, string.split(trimmed, badge_start) {
    False, _ -> Error(MissingBadgeHeading)
    True, [_no_badge] -> Error(badge_absent_reason(trimmed))
    True, parts -> badge_address(parts, hashes)
  }
}

fn badge_absent_reason(heading: String) -> Reason {
  case string.contains(heading, "Tested snippet") {
    True -> MalformedBadge
    False -> MissingBadgeHeading
  }
}

fn badge_address(parts: List(String), hashes: Int) -> Result(String, Reason) {
  let badge = list.last(parts) |> result.unwrap("")
  let title =
    parts
    |> list.take(list.length(parts) - 1)
    |> string.join(badge_start)
    |> string.drop_start(hashes)
    |> string.trim
  use address <- result.try(
    remove_suffix(badge, badge_end)
    |> result.replace_error(badge_mismatch_reason(badge)),
  )
  case title == "" || address == "" || string.contains(address, "\"") {
    True -> Error(MalformedBadge)
    False -> Ok(address)
  }
}

fn badge_mismatch_reason(badge: String) -> Reason {
  case string.contains(badge, "<img") {
    True -> MalformedBadge
    False -> MissingBadgeHeading
  }
}

/// Reads a badge link address into a snippet link. The address must be a
/// file in the dream GitHub repository, with a path that stays inside the
/// repository.
pub fn parse_snippet_link(address: String) -> Result(SnippetLink, Reason) {
  use after_prefix <- result.try(
    remove_prefix(address, repository_blob_prefix)
    |> result.replace_error(ForeignLink(address)),
  )
  use #(tag, path_and_anchor) <- result.try(
    string.split_once(after_prefix, "/")
    |> result.replace_error(ForeignLink(address)),
  )
  let #(path, anchor) = split_anchor(path_and_anchor)
  case is_repository_path(path) {
    True -> Ok(SnippetLink(tag:, path:, anchor:))
    False -> Error(ForeignLink(address))
  }
}

fn split_anchor(text: String) -> #(String, String) {
  case string.split_once(text, "#") {
    Ok(#(path, fragment)) -> #(path, "#" <> fragment)
    Error(Nil) -> #(text, "")
  }
}

fn is_repository_path(path: String) -> Bool {
  let segments = string.split(path, "/")
  path != ""
  && !string.contains(path, "?")
  && !list.contains(segments, "..")
  && !list.contains(segments, ".")
  && !list.contains(segments, "")
}

/// Reads a line anchor: an empty string for the whole file, `#L<n>` for
/// one line, or `#L<start>-L<end>` for a range. Line numbers are positive
/// and have no leading zero.
pub fn parse_line_selection(anchor: String) -> Result(LineSelection, Reason) {
  case anchor {
    "" -> Ok(WholeFile)
    "#L" <> lines -> parse_line_range(lines, anchor)
    _ -> Error(MalformedLineRange(anchor))
  }
}

fn parse_line_range(
  lines: String,
  anchor: String,
) -> Result(LineSelection, Reason) {
  let numbers = case string.split_once(lines, "-L") {
    Ok(#(start, end)) -> #(parse_line_number(start), parse_line_number(end))
    Error(Nil) -> #(parse_line_number(lines), parse_line_number(lines))
  }
  case numbers {
    #(Ok(start), Ok(end)) if start > end ->
      Error(ReversedLineRange(start:, end:))
    #(Ok(start), Ok(end)) -> Ok(LineRange(start:, end:))
    _ -> Error(MalformedLineRange(anchor))
  }
}

fn parse_line_number(text: String) -> Result(Int, Nil) {
  use number <- result.try(int.parse(text))
  case number > 0 && int.to_string(number) == text {
    True -> Ok(number)
    False -> Error(Nil)
  }
}

/// Checks one snippet link against its block. The tag is checked on its
/// own; the line anchor, the file and the content are checked in order,
/// each only when the one before it passed.
fn check_link(
  link: SnippetLink,
  block: FencedBlock,
  context: CheckContext,
) -> List(Reason) {
  let tag_problems = case link.tag == context.version {
    True -> []
    False -> [WrongTag(found: link.tag, expected: context.version)]
  }
  let content_problems = case check_content(link, block, context) {
    Ok(Nil) -> []
    Error(reason) -> [reason]
  }
  list.append(tag_problems, content_problems)
}

fn check_content(
  link: SnippetLink,
  block: FencedBlock,
  context: CheckContext,
) -> Result(Nil, Reason) {
  use selection <- result.try(parse_line_selection(link.anchor))
  use source <- result.try(
    context.read_source(link.path)
    |> result.map_error(fn(error) { source_error_reason(link.path, error) }),
  )
  use expected <- result.try(expected_lines(source, selection, block))
  let block_lines = list.map(block.content, fn(line) { line.text })
  let actual = case selection {
    WholeFile -> list.append(block_lines, [""])
    LineRange(..) -> block_lines
  }
  case first_difference(actual, expected, 0) {
    None -> Ok(Nil)
    Some(index) ->
      Error(BlockDiffers(
        path: link.path,
        anchor: link.anchor,
        first_difference_line: document_line(block, index),
      ))
  }
}

fn source_error_reason(path: String, error: simplifile.FileError) -> Reason {
  case error {
    simplifile.Enoent | simplifile.Eisdir | simplifile.Enotdir ->
      MissingFile(path)
    _ -> UnreadableFile(path:, reason: error)
  }
}

/// The lines that the block must have.
///
/// For a line range, they are the lines of that range. For the whole file,
/// they are the file split on each newline, so the last item is the empty
/// text after the final newline; the caller adds an empty item to the
/// block lines to match it. A whole-file block may leave out the leading
/// `////` module comment and the blank line after it: it is compared
/// without them when its first line is not a `////` line.
fn expected_lines(
  source: String,
  selection: LineSelection,
  block: FencedBlock,
) -> Result(List(String), Reason) {
  case selection {
    WholeFile -> Ok(whole_file_lines(source, block))
    LineRange(start:, end:) -> range_lines(source, start, end)
  }
}

fn whole_file_lines(source: String, block: FencedBlock) -> List(String) {
  let lines = string.split(source, "\n")
  case starts_with_module_comment(block) {
    True -> lines
    False -> without_module_comment(lines)
  }
}

fn starts_with_module_comment(block: FencedBlock) -> Bool {
  case block.content {
    [first, ..] -> string.starts_with(first.text, "////")
    [] -> False
  }
}

fn without_module_comment(lines: List(String)) -> List(String) {
  let rest =
    list.drop_while(lines, fn(line) { string.starts_with(line, "////") })
  case list.length(rest) == list.length(lines), rest {
    True, _ -> lines
    False, ["", ..after_blank] -> after_blank
    False, _ -> rest
  }
}

fn range_lines(
  source: String,
  start: Int,
  end: Int,
) -> Result(List(String), Reason) {
  let lines = source_lines(source)
  let line_count = list.length(lines)
  case end > line_count {
    True -> Error(LineRangePastEnd(end:, line_count:))
    False -> Ok(lines |> list.drop(start - 1) |> list.take(end - start + 1))
  }
}

/// The lines of a file as GitHub numbers them: a final newline does not
/// start another line.
fn source_lines(source: String) -> List(String) {
  let content = case string.ends_with(source, "\n") {
    True -> string.drop_end(source, 1)
    False -> source
  }
  string.split(content, "\n")
}

fn first_difference(
  actual: List(String),
  expected: List(String),
  index: Int,
) -> Option(Int) {
  case actual, expected {
    [], [] -> None
    [first_actual, ..rest_actual], [first_expected, ..rest_expected]
      if first_actual == first_expected
    -> first_difference(rest_actual, rest_expected, index + 1)
    _, _ -> Some(index)
  }
}

fn document_line(block: FencedBlock, index: Int) -> Int {
  case list.drop(block.content, index) {
    [line, ..] -> line.number
    [] -> block.closing_line
  }
}

// ---------------------------------------------------------------------------
// Gleam code outside gleam fences
// ---------------------------------------------------------------------------

/// Tells whether a line looks like Gleam code.
///
/// It matches only forms that the other languages in the docs (shell,
/// TOML, YAML, JavaScript, TypeScript, SQL, Elixir, Gherkin, Markdown,
/// Dockerfile, diagrams) do not have, so that their fences pass:
///
/// - `import a/b` or `import a.{...}`. JavaScript imports use quotes and
///   `from`, and Python imports have no `/` and no `.{`.
/// - `fn name(` or `pub fn name(`. Elixir writes `fn x ->` and `fn(`,
///   JavaScript writes `function`.
/// - `pub type Name`, `pub opaque type Name`, or `type Name` with no `=`.
///   TypeScript type aliases always have `=`.
/// - `use name <- ...`. Rust `use` lines have no `<-`.
/// - `let assert ...`.
/// - `|> module.function(`, a pipe into a lowercase module. Elixir and F#
///   pipes call capitalised modules (`|> Enum.map(`).
///
/// Rust also has `fn name(`; the docs have no Rust code.
pub fn looks_like_gleam(text: String) -> Bool {
  let code = string.trim_start(text)
  is_gleam_import(code)
  || is_gleam_function(code)
  || is_gleam_type(code)
  || is_gleam_use(code)
  || string.starts_with(code, "let assert ")
  || has_gleam_pipe(code)
}

fn is_gleam_import(code: String) -> Bool {
  case code {
    "import " <> rest -> {
      let #(module, after) = take_while_in(rest, module_path_characters, "")
      starts_with_lowercase(module)
      && { string.contains(module, "/") || string.starts_with(after, ".{") }
    }
    _ -> False
  }
}

fn is_gleam_function(code: String) -> Bool {
  case code {
    "pub fn " <> rest | "fn " <> rest -> {
      let #(name, after) = take_while_in(rest, name_characters, "")
      starts_with_lowercase(name) && string.starts_with(after, "(")
    }
    _ -> False
  }
}

fn is_gleam_type(code: String) -> Bool {
  case code {
    "pub type " <> rest | "pub opaque type " <> rest | "type " <> rest ->
      starts_with_uppercase(rest) && !string.contains(rest, "=")
    _ -> False
  }
}

fn is_gleam_use(code: String) -> Bool {
  string.starts_with(code, "use ") && string.contains(code, " <- ")
}

fn has_gleam_pipe(code: String) -> Bool {
  case string.split(code, "|> ") {
    [_, ..piped] -> list.any(piped, is_module_call)
    [] -> False
  }
}

fn is_module_call(code: String) -> Bool {
  let #(module, after_module) = take_while_in(code, name_characters, "")
  let #(function, after_function) =
    take_while_in(string.drop_start(after_module, 1), name_characters, "")
  starts_with_lowercase(module)
  && string.starts_with(after_module, ".")
  && starts_with_lowercase(function)
  && string.starts_with(after_function, "(")
}

const lowercase_letters = "abcdefghijklmnopqrstuvwxyz"

const uppercase_letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

const name_characters = "abcdefghijklmnopqrstuvwxyz0123456789_"

const module_path_characters = "abcdefghijklmnopqrstuvwxyz0123456789_/"

fn take_while_in(
  text: String,
  characters: String,
  taken: String,
) -> #(String, String) {
  case string.pop_grapheme(text) {
    Ok(#(first, rest)) -> take_if_in(first, rest, text, characters, taken)
    Error(Nil) -> #(taken, text)
  }
}

fn take_if_in(
  first: String,
  rest: String,
  text: String,
  characters: String,
  taken: String,
) -> #(String, String) {
  case string.contains(characters, first) {
    True -> take_while_in(rest, characters, taken <> first)
    False -> #(taken, text)
  }
}

fn starts_with_lowercase(text: String) -> Bool {
  starts_with_one_of(text, lowercase_letters)
}

fn starts_with_uppercase(text: String) -> Bool {
  starts_with_one_of(text, uppercase_letters)
}

fn starts_with_one_of(text: String, characters: String) -> Bool {
  case string.pop_grapheme(text) {
    Ok(#(first, _)) -> string.contains(characters, first)
    Error(Nil) -> False
  }
}

fn option_to_list(value: Option(a)) -> List(a) {
  case value {
    Some(item) -> [item]
    None -> []
  }
}
