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
//// A ```` ```diff ```` block shows how code changed between two releases,
//// for example in an upgrade guide. Old code does not compile on the new
//// version, so it cannot be a tested snippet. It is an excerpt of the real
//// git diff instead. Its heading ends with the "tested diff" badge, which
//// links to GitHub's compare view of one file, for example
//// `https://github.com/TrustBound/dream/compare/2.4.1...3.0.0#diff-<digest>`,
//// where `<digest>` is the SHA-256 hex digest of the file's path (GitHub's
//// own anchor for the file). The block starts with the `--- a/<path>` and
//// `+++ b/<path>` lines, then holds lines of the diff, with or without
//// `@@` hunk headers. The check runs `git diff <old tag> -- <path>` against
//// the working tree, and each run of lines must be in that diff, in order
//// and contiguous within one hunk. The new tag is the version in
//// `gleam.toml`, because that tag does not exist before the release.
////
//// Release notes and changelog entries for version 3.0.0 and later are
//// checked. Older ones show code that was right for their own version, so
//// they are not (see `checked_from_version`).
////
//// The module lives in `test/` so that it never ships in the Hex package.
//// The logic is in pure functions (`check_markdown`, `check_changelog`,
//// `check_gleam_source`, `sort_problems`, `describe_problem`). They get
//// files and git through a `CheckContext`, so the tests can give them fake
//// files and a fake git history. The `main` function only lists and reads
//// files, gives the real git to the context, and prints the result.

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
  /// A release notes file, `release-<version>.md`. It is checked like a
  /// Markdown document when its version is `checked_from_version` or later,
  /// and skipped when it is older or has no version in its name.
  ReleaseNotes
  /// The changelog. Its `## [<version>]` sections for `checked_from_version`
  /// and later, its `## [Unreleased]` section and the text before the first
  /// section are checked. The sections of older versions are skipped.
  Changelog
}

/// A release version, `major.minor.patch`.
pub type Version {
  Version(major: Int, minor: Int, patch: Int)
}

/// The first version whose release notes and changelog section are
/// checked. Older notes show the code of their own version, which does not
/// compile now, and nobody rewrites them.
const checked_from_version = Version(3, 0, 0)

/// A file, or a directory that is walked for files of one kind.
pub type CheckedRoot {
  CheckedRoot(path: String, kind: DocumentKind)
}

/// The places that the check reads, relative to the repository root. This
/// is the one list to change to widen or narrow the check.
///
/// `releases/` and `CHANGELOG.md` are checked only from
/// `checked_from_version` on (see `ReleaseNotes` and `Changelog`).
///
/// These are not checked, on purpose:
///
/// - `.cursor/`: it holds prompts for coding agents, not docs.
/// - `build/` and dependency folders: see `skipped_directory_names`.
const checked_roots = [
  CheckedRoot("README.md", MarkdownDocument),
  CheckedRoot("SECURITY.md", MarkdownDocument),
  CheckedRoot("CHANGELOG.md", Changelog),
  CheckedRoot("docs", MarkdownDocument),
  CheckedRoot("examples", MarkdownDocument),
  CheckedRoot("releases", ReleaseNotes),
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
const badge_end =
  "\"><img align=\"right\" alt=\"Tested snippet\" src=\"https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square\"></a>"

/// The start of every diff badge link: GitHub's compare view of the dream
/// repository.
const repository_compare_prefix = "https://github.com/TrustBound/dream/compare/"

/// The exact text after the link address of a diff badge, to the end of the
/// heading.
const diff_badge_end =
  "\"><img align=\"right\" alt=\"Tested diff\" src=\"https://img.shields.io/badge/%F0%9F%A7%AA_tested-diff-lightgreen.svg?style=flat-square\"></a>"

/// The start of the anchor that names one file in a compare view. The
/// SHA-256 hex digest of the file's path follows it.
const diff_anchor_prefix = "diff-"

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// One line of a document, with its 1-based line number in the file.
pub type Line {
  Line(number: Int, text: String)
}

/// What the checks need from the outside.
///
/// `release_tag` is the tag that badge links in the document must use: the
/// version in the root `gleam.toml`. `read_source` reads a file by its path
/// relative to the repository root. `tag_exists` tells whether a
/// git tag is in the local clone. `diff_from_tag` returns the text of the
/// git diff of one path (the second argument) from a tag (the first
/// argument) to the working tree. `main` gives them `simplifile.read`,
/// `git_tag_exists` and `git_diff_from_tag`. The tests give them lookups in
/// lists, so they do not depend on the files or the history of this
/// repository.
pub type CheckContext {
  CheckContext(
    release_tag: String,
    read_source: fn(String) -> Result(String, simplifile.FileError),
    tag_exists: fn(String) -> Result(Bool, GitError),
    diff_from_tag: fn(String, String) -> Result(String, GitError),
  )
}

/// Why git could not answer.
pub type GitError {
  /// The `git` program is not on the `PATH`.
  GitNotFound
  /// git stopped with an exit status that is not 0. `output` is what it
  /// wrote to standard output.
  GitFailed(status: Int, output: String)
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
  /// The tag in the badge link is not the release tag of the document (see
  /// `CheckContext`).
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
  /// A diff block has no heading with the diff badge directly above it.
  MissingDiffBadgeHeading
  /// The heading has a diff badge, but not in the exact format.
  MalformedDiffBadge
  /// The diff badge does not link to a compare view of this repository, as
  /// `<old tag>...<new tag>#diff-<digest>`, or a tag has characters that a
  /// tag name in this repository does not have.
  NotCompareLink(url: String)
  /// The new tag in the compare link is not the release tag of the document
  /// (see `CheckContext`).
  WrongNewTag(found: String, expected: String)
  /// The diff block does not start with `--- a/<path>` and `+++ b/<path>`
  /// for one path, or the path has characters that are not allowed.
  MissingDiffFileHeader
  /// The diff block has no lines after its file header.
  EmptyDiffBlock
  /// The anchor in the compare link is not the digest of the path in the
  /// block. `expected` is the right anchor, with its `#`.
  WrongDiffAnchor(path: String, expected: String)
  /// The old tag in the compare link is not in the local clone.
  MissingOldTag(tag: String)
  /// git could not be run, or it failed.
  GitUnavailable(error: GitError)
  /// The file did not change between the old tag and now.
  NoDiffForPath(path: String, old_tag: String)
  /// A hunk header in the block is not a hunk header of the real diff, or
  /// it is out of order.
  HunkHeaderNotFound(header: String)
  /// A line of the block is not in the real diff at that place.
  DiffLineNotFound(path: String, old_tag: String)
}

/// One problem: the file, the 1-based line, and why.
pub type Problem {
  Problem(file: String, line: Int, reason: Reason)
}

/// The result of checking one or more documents.
///
/// `blocks_checked` counts the Gleam code blocks that were checked, and
/// `diff_blocks_checked` the diff blocks.
pub type Report {
  Report(blocks_checked: Int, diff_blocks_checked: Int, problems: List(Problem))
}

/// A link to GitHub's compare view of one file, read from a diff badge.
///
/// `anchor_digest` is the part of the anchor after `#diff-`.
pub type CompareLink {
  CompareLink(old_tag: String, new_tag: String, anchor_digest: String)
}

/// One hunk of a real git diff: its `@@` header line and the lines after
/// it, each with its `-`, `+` or space prefix.
pub type DiffHunk {
  DiffHunk(header: String, lines: List(String))
}

/// A run of lines in a diff block: an optional `@@` header line and the
/// lines after it, up to the next header.
type DiffSegment {
  DiffSegment(header: Option(Line), lines: List(Line))
}

/// The kind of badge that a heading must end with.
type BadgeKind {
  SnippetBadge
  DiffBadge
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
  io.println(summary(
    report.blocks_checked,
    report.diff_blocks_checked,
    file_count,
    list.length(problems),
  ))
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
  let context =
    CheckContext(
      release_tag: version,
      read_source: simplifile.read,
      tag_exists: git_tag_exists,
      diff_from_tag: git_diff_from_tag,
    )
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
    MarkdownDocument | ReleaseNotes -> check_markdown(path, text, context)
    Changelog -> check_changelog(path, text, context)
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
  case string.ends_with(path, file_extension(kind)) && is_in_scope(path, kind) {
    True -> [#(path, kind)]
    False -> []
  }
}

fn file_extension(kind: DocumentKind) -> String {
  case kind {
    MarkdownDocument | ReleaseNotes | Changelog -> ".md"
    GleamSource -> ".gleam"
  }
}

fn is_in_scope(path: String, kind: DocumentKind) -> Bool {
  case kind {
    ReleaseNotes -> is_checked_release_notes(path)
    MarkdownDocument | GleamSource | Changelog -> True
  }
}

// ---------------------------------------------------------------------------
// Release notes and the changelog
// ---------------------------------------------------------------------------

/// Tells whether a release notes file is checked: its name is
/// `release-<version>.md` and the version is `checked_from_version` or
/// later. Versions are compared as numbers, so `10.0.0` is after `3.0.0`.
pub fn is_checked_release_notes(path: String) -> Bool {
  case release_notes_version(path) {
    Ok(version) -> is_checked_version(version)
    Error(Nil) -> False
  }
}

/// Reads the version from the name of a release notes file, for example
/// `Version(3, 0, 0)` from `releases/release-3.0.0.md`.
pub fn release_notes_version(path: String) -> Result(Version, Nil) {
  let file_name = path |> string.split("/") |> list.last |> result.unwrap(path)
  use rest <- result.try(remove_prefix(file_name, "release-"))
  use version_text <- result.try(remove_suffix(rest, ".md"))
  parse_release_version(version_text)
}

/// Reads `major.minor.patch`. A pre-release part after a `-`, such as
/// `-rc.1`, is ignored, so a pre-release counts as its release.
pub fn parse_release_version(text: String) -> Result(Version, Nil) {
  let core = case string.split_once(text, "-") {
    Ok(#(core, _pre_release)) -> core
    Error(Nil) -> text
  }
  case core |> string.split(".") |> list.try_map(parse_version_number) {
    Ok([major, minor, patch]) -> Ok(Version(major:, minor:, patch:))
    _ -> Error(Nil)
  }
}

fn parse_version_number(text: String) -> Result(Int, Nil) {
  use number <- result.try(int.parse(text))
  case number >= 0 && int.to_string(number) == text {
    True -> Ok(number)
    False -> Error(Nil)
  }
}

/// Compares two versions by major, then minor, then patch number.
pub fn compare_versions(first: Version, second: Version) -> Order {
  int.compare(first.major, second.major)
  |> order.break_tie(int.compare(first.minor, second.minor))
  |> order.break_tie(int.compare(first.patch, second.patch))
}

fn is_checked_version(version: Version) -> Bool {
  compare_versions(version, checked_from_version) != order.Lt
}

/// Checks the changelog. Its sections start at `## [<name>]` lines. The
/// sections of versions before `checked_from_version` are left out, and the
/// rest of the file is checked like a Markdown document. Each line keeps its
/// line number in the file.
pub fn check_changelog(
  file: String,
  text: String,
  context: CheckContext,
) -> Report {
  let #(_last_checked, marked_lines) =
    list.map_fold(numbered_lines(text, 1), True, fn(checked, line) {
      let checked = is_checked_from_line(line.text, checked)
      #(checked, #(checked, line))
    })
  let lines =
    marked_lines
    |> list.filter(fn(marked) { marked.0 })
    |> list.map(fn(marked) { marked.1 })
  scan(lines, [], TopLevel, file, context, empty_report())
}

/// Whether a line is in a checked section: a section heading decides it
/// for the lines that follow, and any other line keeps the decision of the
/// line before it.
fn is_checked_from_line(text: String, checked_before: Bool) -> Bool {
  case changelog_section_name(text) {
    Ok(name) -> is_checked_changelog_section(name)
    Error(Nil) -> checked_before
  }
}

/// Reads the name of a changelog section heading, for example `3.0.0` from
/// `## [3.0.0] - 2026-11-20`.
pub fn changelog_section_name(text: String) -> Result(String, Nil) {
  use rest <- result.try(remove_prefix(text, "## ["))
  use #(name, _after) <- result.map(string.split_once(rest, "]"))
  name
}

/// Tells whether a changelog section is checked: `Unreleased`, a version
/// from `checked_from_version` on, or a name that is not a version.
pub fn is_checked_changelog_section(name: String) -> Bool {
  case parse_release_version(name) {
    Ok(version) -> is_checked_version(version)
    Error(Nil) -> True
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
  top_level_value(gleam_toml, "version")
  |> result.replace_error(VersionNotFound(gleam_toml_path))
}

/// Reads the value of a `key = "..."` line before the first `[section]`.
fn top_level_value(gleam_toml: String, key: String) -> Result(String, Nil) {
  gleam_toml
  |> string.split("\n")
  |> list.take_while(fn(line) { !string.starts_with(line, "[") })
  |> list.find_map(fn(line) { quoted_value(line, key) })
}

fn quoted_value(line: String, key: String) -> Result(String, Nil) {
  use rest <- result.try(remove_prefix(string.trim(line), key))
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
/// `412 blocks and 5 diff blocks checked in 230 files, 0 problems`.
pub fn summary(
  blocks: Int,
  diff_blocks: Int,
  files: Int,
  problems: Int,
) -> String {
  int.to_string(blocks)
  <> " blocks and "
  <> int.to_string(diff_blocks)
  <> " diff blocks checked in "
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

/// The end of the message of a wrong tag: where the expected tag comes
/// from.
const tag_rule = " (the docs of dream use the version in gleam.toml)"

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
      <> ", but this file must link at the tag "
      <> expected
      <> tag_rule
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
    MissingDiffBadgeHeading ->
      "this diff block has no heading with the tested diff badge directly above it (one blank line between is allowed)"
    MalformedDiffBadge ->
      "the tested diff badge is not in the exact format; copy it from docs/contributing/contributing.md"
    NotCompareLink(url:) ->
      "the diff badge link "
      <> url
      <> " is not https://github.com/TrustBound/dream/compare/<old tag>...<new tag>#diff-<digest>"
    WrongNewTag(found:, expected:) ->
      "the compare link ends at the tag "
      <> found
      <> ", but this file must use the new tag "
      <> expected
      <> tag_rule
    MissingDiffFileHeader ->
      "the diff block does not start with \"--- a/<path>\" and \"+++ b/<path>\" for one path of letters, digits and . _ - /"
    EmptyDiffBlock -> "the diff block has no diff lines after its file header"
    WrongDiffAnchor(path:, expected:) ->
      "the compare link anchor is not the one for "
      <> path
      <> "; use "
      <> expected
    MissingOldTag(tag:) ->
      "the tag "
      <> tag
      <> " is not in this clone; fetch the tags with \"git fetch --tags\" (a shallow clone has none)"
    GitUnavailable(error:) ->
      "cannot read the git diff: " <> describe_git_error(error)
    NoDiffForPath(path:, old_tag:) ->
      path <> " has no changes since the tag " <> old_tag
    HunkHeaderNotFound(header:) ->
      "the hunk header "
      <> header
      <> " is not a hunk header of the real diff, or it is out of order"
    DiffLineNotFound(path:, old_tag:) ->
      "this line is not in \"git diff "
      <> old_tag
      <> " -- "
      <> path
      <> "\" at this place; a diff block shows lines of the real diff, in order and contiguous within a hunk"
  }
}

/// Describes why git could not answer, in a few words.
pub fn describe_git_error(error: GitError) -> String {
  case error {
    GitNotFound -> "git is not on the PATH"
    GitFailed(status:, output: _) ->
      "git stopped with exit status " <> int.to_string(status)
  }
}

fn describe_fence_language(language: String) -> String {
  case language {
    "" -> "a code fence with no language"
    _ -> "a " <> language <> " code fence"
  }
}

fn merge_reports(reports: List(Report)) -> Report {
  list.fold(reports, empty_report(), add_report)
}

fn add_report(total: Report, report: Report) -> Report {
  Report(
    blocks_checked: total.blocks_checked + report.blocks_checked,
    diff_blocks_checked: total.diff_blocks_checked + report.diff_blocks_checked,
    problems: list.append(total.problems, report.problems),
  )
}

fn problems_report(problems: List(Problem)) -> Report {
  Report(blocks_checked: 0, diff_blocks_checked: 0, problems:)
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
  problems_report([])
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
      problems_report([
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
        diff_blocks_checked: 0,
        problems: check_gleam_block(block, above, after, file, context),
      )
    "diff" ->
      Report(
        blocks_checked: 0,
        diff_blocks_checked: 1,
        problems: check_diff_block(block, above, file, context),
      )
    "markdown" | "md" ->
      scan(block.content, [], InsideExample, file, context, empty_report())
    language -> problems_report(hidden_gleam(block, language, file))
  }
  add_report(problems_report(unclosed), report)
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
  parse_heading_with_badge(text, SnippetBadge)
}

/// Reads a heading line that ends with the diff badge, and returns the link
/// address of the badge. The rules are those of `parse_badge_heading`, with
/// `diff_badge_end` in place of `badge_end`.
pub fn parse_diff_badge_heading(text: String) -> Result(String, Reason) {
  parse_heading_with_badge(text, DiffBadge)
}

fn parse_heading_with_badge(
  text: String,
  kind: BadgeKind,
) -> Result(String, Reason) {
  let trimmed = string.trim(text)
  let hashes = count_leading(trimmed, "#", 0)
  let is_heading =
    hashes >= 1
    && hashes <= 6
    && string.starts_with(string.drop_start(trimmed, hashes), " ")
  case is_heading, string.split(trimmed, badge_start) {
    False, _ -> Error(missing_badge_reason(kind))
    True, [_no_badge] -> Error(badge_absent_reason(trimmed, kind))
    True, parts -> badge_address(parts, hashes, kind)
  }
}

fn badge_end_for(kind: BadgeKind) -> String {
  case kind {
    SnippetBadge -> badge_end
    DiffBadge -> diff_badge_end
  }
}

fn badge_alt_for(kind: BadgeKind) -> String {
  case kind {
    SnippetBadge -> "Tested snippet"
    DiffBadge -> "Tested diff"
  }
}

fn missing_badge_reason(kind: BadgeKind) -> Reason {
  case kind {
    SnippetBadge -> MissingBadgeHeading
    DiffBadge -> MissingDiffBadgeHeading
  }
}

fn malformed_badge_reason(kind: BadgeKind) -> Reason {
  case kind {
    SnippetBadge -> MalformedBadge
    DiffBadge -> MalformedDiffBadge
  }
}

fn badge_absent_reason(heading: String, kind: BadgeKind) -> Reason {
  case string.contains(heading, badge_alt_for(kind)) {
    True -> malformed_badge_reason(kind)
    False -> missing_badge_reason(kind)
  }
}

fn badge_address(
  parts: List(String),
  hashes: Int,
  kind: BadgeKind,
) -> Result(String, Reason) {
  let badge = list.last(parts) |> result.unwrap("")
  let title =
    parts
    |> list.take(list.length(parts) - 1)
    |> string.join(badge_start)
    |> string.drop_start(hashes)
    |> string.trim
  use address <- result.try(
    remove_suffix(badge, badge_end_for(kind))
    |> result.replace_error(badge_mismatch_reason(badge, kind)),
  )
  case title == "" || address == "" || string.contains(address, "\"") {
    True -> Error(malformed_badge_reason(kind))
    False -> Ok(address)
  }
}

fn badge_mismatch_reason(badge: String, kind: BadgeKind) -> Reason {
  case string.contains(badge, "<img") {
    True -> malformed_badge_reason(kind)
    False -> missing_badge_reason(kind)
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
  let tag_problems = case link.tag == context.release_tag {
    True -> []
    False -> [WrongTag(found: link.tag, expected: context.release_tag)]
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
// Diff blocks
// ---------------------------------------------------------------------------

/// Checks a diff block: its heading and diff badge, the compare link, and
/// that its lines are in the real git diff of the file it names.
fn check_diff_block(
  block: FencedBlock,
  above: List(Line),
  file: String,
  context: CheckContext,
) -> List(Problem) {
  case first_line_skipping_one_blank(above) {
    None -> [
      Problem(file:, line: block.opening_line, reason: MissingDiffBadgeHeading),
    ]
    Some(heading) -> diff_heading_problems(heading, block, file, context)
  }
}

fn diff_heading_problems(
  heading: Line,
  block: FencedBlock,
  file: String,
  context: CheckContext,
) -> List(Problem) {
  let link =
    parse_diff_badge_heading(heading.text)
    |> result.try(parse_compare_link)
  case link {
    Ok(link) ->
      check_compare_link(link, block, context)
      |> list.map(fn(found) { Problem(file:, line: found.0, reason: found.1) })
    Error(reason) -> [Problem(file:, line: block.opening_line, reason:)]
  }
}

/// Reads a diff badge link address into a compare link. The address must
/// be `https://github.com/TrustBound/dream/compare/<old>...<new>#diff-<hex>`
/// and both tags must be safe tag names (see `is_safe_tag`).
pub fn parse_compare_link(address: String) -> Result(CompareLink, Reason) {
  let not_compare_link = NotCompareLink(address)
  use after_prefix <- result.try(
    remove_prefix(address, repository_compare_prefix)
    |> result.replace_error(not_compare_link),
  )
  use #(range, anchor) <- result.try(
    string.split_once(after_prefix, "#")
    |> result.replace_error(not_compare_link),
  )
  use #(old_tag, new_tag) <- result.try(
    string.split_once(range, "...")
    |> result.replace_error(not_compare_link),
  )
  use anchor_digest <- result.try(
    remove_prefix(anchor, diff_anchor_prefix)
    |> result.replace_error(not_compare_link),
  )
  case is_safe_tag(old_tag) && is_safe_tag(new_tag) && anchor_digest != "" {
    True -> Ok(CompareLink(old_tag:, new_tag:, anchor_digest:))
    False -> Error(not_compare_link)
  }
}

/// Tells whether a text is a safe tag name to give to git: letters, digits,
/// `.`, `_` and `-`, not starting with `-` and with no `..`.
pub fn is_safe_tag(tag: String) -> Bool {
  tag != ""
  && is_made_of(tag, tag_characters)
  && !string.starts_with(tag, "-")
  && !string.contains(tag, "..")
}

/// Tells whether a text is a safe repository path to give to git: a path
/// inside the repository (see `is_repository_path`) made of letters,
/// digits, `.`, `_`, `-` and `/`, not starting with `-`.
pub fn is_safe_path(path: String) -> Bool {
  is_repository_path(path)
  && is_made_of(path, path_characters)
  && !string.starts_with(path, "-")
}

const tag_characters =
  "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"

const path_characters =
  "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-/"

fn is_made_of(text: String, characters: String) -> Bool {
  text
  |> string.to_graphemes
  |> list.all(fn(character) { string.contains(characters, character) })
}

/// Checks a compare link against its block. The new tag is checked on its
/// own. The file header, the anchor, the old tag, the diff and the lines
/// are checked in order, each only when the one before it passed. Each
/// problem comes with the line of the document that it is about.
fn check_compare_link(
  link: CompareLink,
  block: FencedBlock,
  context: CheckContext,
) -> List(#(Int, Reason)) {
  let tag_problems = case link.new_tag == context.release_tag {
    True -> []
    False -> [
      #(
        block.opening_line,
        WrongNewTag(found: link.new_tag, expected: context.release_tag),
      ),
    ]
  }
  let content_problems = case check_diff_content(link, block, context) {
    Ok(Nil) -> []
    Error(problem) -> [problem]
  }
  list.append(tag_problems, content_problems)
}

fn check_diff_content(
  link: CompareLink,
  block: FencedBlock,
  context: CheckContext,
) -> Result(Nil, #(Int, Reason)) {
  let at_block = fn(reason) { #(block.opening_line, reason) }
  use #(path, body) <- result.try(
    parse_diff_file_header(block.content) |> result.map_error(at_block),
  )
  use Nil <- result.try(
    check_diff_anchor(link, path) |> result.map_error(at_block),
  )
  use Nil <- result.try(
    require_old_tag(link.old_tag, context) |> result.map_error(at_block),
  )
  use diff_text <- result.try(
    context.diff_from_tag(link.old_tag, path)
    |> result.map_error(fn(error) { at_block(GitUnavailable(error)) }),
  )
  case parse_hunks(diff_text) {
    [] -> Error(at_block(NoDiffForPath(path:, old_tag: link.old_tag)))
    hunks -> {
      let line_not_found = DiffLineNotFound(path:, old_tag: link.old_tag)
      match_segments(diff_segments(body), hunks, line_not_found)
    }
  }
}

/// Reads the `--- a/<path>` and `+++ b/<path>` lines at the start of a diff
/// block, and returns the path and the lines after them.
fn parse_diff_file_header(
  content: List(Line),
) -> Result(#(String, List(Line)), Reason) {
  case content {
    [old_file, new_file, ..body] ->
      diff_file_path(old_file.text, new_file.text)
      |> result.try(fn(path) { require_diff_body(path, body) })
    _ -> Error(MissingDiffFileHeader)
  }
}

fn diff_file_path(
  old_file: String,
  new_file: String,
) -> Result(String, Reason) {
  let old_path = remove_prefix(old_file, "--- a/")
  let new_path = remove_prefix(new_file, "+++ b/")
  case old_path, new_path {
    Ok(old_path), Ok(new_path) if old_path == new_path ->
      safe_path_or_error(old_path)
    _, _ -> Error(MissingDiffFileHeader)
  }
}

fn safe_path_or_error(path: String) -> Result(String, Reason) {
  case is_safe_path(path) {
    True -> Ok(path)
    False -> Error(MissingDiffFileHeader)
  }
}

fn require_diff_body(
  path: String,
  body: List(Line),
) -> Result(#(String, List(Line)), Reason) {
  case body {
    [] -> Error(EmptyDiffBlock)
    _ -> Ok(#(path, body))
  }
}

/// The SHA-256 hex digest of a repository path. GitHub's compare view
/// gives each file the anchor `#diff-` followed by this digest.
pub fn path_digest(path: String) -> String {
  sha256_hex(path)
}

@external(erlang, "docs_snippet_check_ffi", "sha256_hex")
fn sha256_hex(text: String) -> String

fn check_diff_anchor(link: CompareLink, path: String) -> Result(Nil, Reason) {
  let digest = path_digest(path)
  case link.anchor_digest == digest {
    True -> Ok(Nil)
    False ->
      Error(WrongDiffAnchor(
        path:,
        expected: "#" <> diff_anchor_prefix <> digest,
      ))
  }
}

fn require_old_tag(tag: String, context: CheckContext) -> Result(Nil, Reason) {
  case context.tag_exists(tag) {
    Ok(True) -> Ok(Nil)
    Ok(False) -> Error(MissingOldTag(tag))
    Error(error) -> Error(GitUnavailable(error))
  }
}

/// Splits the text of a git diff into its hunks. The lines before the first
/// `@@` header (`diff --git`, `index`, `---` and `+++`) are left out.
pub fn parse_hunks(diff_text: String) -> List(DiffHunk) {
  source_lines(diff_text)
  |> list.fold([], add_to_hunks)
  |> list.reverse
  |> list.map(fn(hunk) { DiffHunk(..hunk, lines: list.reverse(hunk.lines)) })
}

/// Adds one line of a diff to the hunks, which are held last first, each
/// with its lines last first.
fn add_to_hunks(hunks: List(DiffHunk), text: String) -> List(DiffHunk) {
  case is_hunk_header(text), hunks {
    True, _ -> [DiffHunk(header: text, lines: []), ..hunks]
    False, [] -> []
    False, [current, ..rest] -> [
      DiffHunk(..current, lines: [text, ..current.lines]),
      ..rest
    ]
  }
}

fn is_hunk_header(text: String) -> Bool {
  string.starts_with(text, "@@")
}

/// Splits the lines of a diff block, after its file header, at each `@@`
/// header. Only the first segment can have no header, and it is left out
/// when it is empty.
fn diff_segments(body: List(Line)) -> List(DiffSegment) {
  body
  |> list.fold([], add_to_segments)
  |> list.reverse
  |> list.map(fn(segment) {
    DiffSegment(..segment, lines: list.reverse(segment.lines))
  })
}

fn add_to_segments(
  segments: List(DiffSegment),
  line: Line,
) -> List(DiffSegment) {
  case is_hunk_header(line.text), segments {
    True, _ -> [DiffSegment(header: Some(line), lines: []), ..segments]
    False, [] -> [DiffSegment(header: None, lines: [line])]
    False, [current, ..rest] -> [
      DiffSegment(..current, lines: [line, ..current.lines]),
      ..rest
    ]
  }
}

/// Finds each segment of a block in the hunks of the real diff, in order.
/// A segment with a header must be in the first later hunk with the same
/// header. A segment with no header can be in any hunk. Its lines must be
/// contiguous within that one hunk. The next segment is looked for in the
/// hunks after it.
fn match_segments(
  segments: List(DiffSegment),
  hunks: List(DiffHunk),
  line_not_found: Reason,
) -> Result(Nil, #(Int, Reason)) {
  case segments {
    [] -> Ok(Nil)
    [segment, ..rest] -> {
      use hunks_after <- result.try(match_segment(
        segment,
        hunks,
        line_not_found,
      ))
      match_segments(rest, hunks_after, line_not_found)
    }
  }
}

fn match_segment(
  segment: DiffSegment,
  hunks: List(DiffHunk),
  line_not_found: Reason,
) -> Result(List(DiffHunk), #(Int, Reason)) {
  let texts = list.map(segment.lines, fn(line) { line.text })
  case segment.header {
    None ->
      find_lines(texts, hunks, 0)
      |> result.map_error(fn(index) {
        #(line_number_at(segment, index), line_not_found)
      })
    Some(header) ->
      match_headed_segment(header, texts, hunks)
      |> result.map_error(fn(missing) {
        headed_segment_problem(segment, header, missing, line_not_found)
      })
  }
}

fn headed_segment_problem(
  segment: DiffSegment,
  header: Line,
  missing: Option(Int),
  line_not_found: Reason,
) -> #(Int, Reason) {
  case missing {
    Some(index) -> #(line_number_at(segment, index), line_not_found)
    None -> #(header.number, HunkHeaderNotFound(header.text))
  }
}

/// Finds the first hunk with the header, and the lines in it. The error is
/// `None` when no hunk has the header, or the index of the first line that
/// is not in the hunk.
fn match_headed_segment(
  header: Line,
  texts: List(String),
  hunks: List(DiffHunk),
) -> Result(List(DiffHunk), Option(Int)) {
  let from_header =
    list.drop_while(hunks, fn(hunk) {
      !header_matches(header.text, hunk.header)
    })
  case from_header {
    [] -> Error(None)
    [hunk, ..after] ->
      find_lines(texts, [hunk], 0)
      |> result.replace(after)
      |> result.map_error(Some)
  }
}

/// A block header matches a real one when it is the same line, or the
/// same `@@ -a,b +c,d @@` part without the function name that git adds.
fn header_matches(block_header: String, real_header: String) -> Bool {
  block_header == real_header || block_header == header_ranges(real_header)
}

fn header_ranges(header: String) -> String {
  case string.split_once(string.drop_start(header, 2), "@@") {
    Ok(#(ranges, _function_name)) -> "@@" <> ranges <> "@@"
    Error(Nil) -> header
  }
}

/// Finds the lines as a contiguous run in one of the hunks, and returns
/// the hunks after that one. When no hunk holds all of them, the error is
/// the index of the first line after the longest run that was found.
fn find_lines(
  texts: List(String),
  hunks: List(DiffHunk),
  best: Int,
) -> Result(List(DiffHunk), Int) {
  case hunks {
    [] -> Error(best)
    [hunk, ..rest] -> {
      let matched = longest_run(texts, hunk.lines, 0)
      case matched == list.length(texts) {
        True -> Ok(rest)
        False -> find_lines(texts, rest, int.max(best, matched))
      }
    }
  }
}

/// The largest number of leading `needle` lines found in a row anywhere in
/// `haystack`.
fn longest_run(needle: List(String), haystack: List(String), best: Int) -> Int {
  case haystack {
    [] -> best
    [_, ..rest] ->
      longest_run(
        needle,
        rest,
        int.max(best, common_prefix_length(needle, haystack, 0)),
      )
  }
}

fn common_prefix_length(
  first: List(String),
  second: List(String),
  count: Int,
) -> Int {
  case first, second {
    [first_line, ..first_rest], [second_line, ..second_rest]
      if first_line == second_line
    -> common_prefix_length(first_rest, second_rest, count + 1)
    _, _ -> count
  }
}

fn line_number_at(segment: DiffSegment, index: Int) -> Int {
  case list.drop(segment.lines, index), segment.header {
    [line, ..], _ -> line.number
    [], Some(header) -> header.number
    [], None -> 0
  }
}

// ---------------------------------------------------------------------------
// git
// ---------------------------------------------------------------------------

/// Tells whether a tag is in the local clone, with
/// `git rev-parse --verify --quiet refs/tags/<tag>^{commit}`. git exits with
/// status 1 and no output when the tag is missing. Any other failure is an
/// error. The tag must pass `is_safe_tag`.
pub fn git_tag_exists(tag: String) -> Result(Bool, GitError) {
  case
    run_git([
      "rev-parse",
      "--verify",
      "--quiet",
      "refs/tags/" <> tag <> "^{commit}",
    ])
  {
    Ok(_commit) -> Ok(True)
    Error(GitFailed(status: 1, output: "")) -> Ok(False)
    Error(error) -> Error(error)
  }
}

/// Returns the text of `git diff` for one path, from a tag to the working
/// tree. The options fix the output format, so that a user's git settings
/// (colours, prefixes, external diff tools, the diff algorithm, the number
/// of context lines) cannot change it. The tag must pass `is_safe_tag` and
/// the path `is_safe_path`. The path comes after `--`, so git never reads
/// it as an option.
pub fn git_diff_from_tag(
  tag: String,
  path: String,
) -> Result(String, GitError) {
  run_git([
    "-c",
    "core.quotepath=off",
    "diff",
    "--no-color",
    "--no-ext-diff",
    "--no-textconv",
    "--no-renames",
    "--src-prefix=a/",
    "--dst-prefix=b/",
    "--unified=3",
    "--diff-algorithm=myers",
    "--indent-heuristic",
    "refs/tags/" <> tag,
    "--",
    path,
  ])
}

/// Runs git with the arguments, with no shell between, and returns its
/// standard output. See `docs_snippet_check_ffi.erl`.
@external(erlang, "docs_snippet_check_ffi", "run_git")
fn run_git(arguments: List(String)) -> Result(String, GitError)

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
