//// Tests for the docs_snippet_check module, which fails when a Gleam code
//// block in the docs is not backed by tested code, or a diff block is not
//// a real excerpt of the git diff.
////
//// Each fixture is a small inline document. The linked snippet files and
//// the git history are held in lists and fake functions, so the tests never
//// read the real docs, snippets or history. Two tests at the end use the
//// real git and the real digest function, on facts that do not change: the
//// tag 2.4.1 exists, and the digest of a path is fixed.

import docs_snippet_check.{
  BlockDiffers, CheckContext, DiffLineNotFound, EmptyDiffBlock, ForeignLink,
  GitNotFound, GitUnavailable, HiddenGleamCode, HunkHeaderNotFound,
  LineRangePastEnd, MalformedBadge, MalformedDiffBadge, MalformedLineRange,
  MissingBadgeHeading, MissingDiffBadgeHeading, MissingDiffFileHeader,
  MissingFile, MissingOldTag, NoDiffForPath, NotCompareLink, OldTestedSourceLine,
  Problem, Report, ReversedLineRange, Version, WrongDiffAnchor, WrongNewTag,
  WrongTag,
}
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}
import gleam/list
import gleam/result
import gleam/string
import simplifile

const snippet_path = "test/snippets/example.gleam"

/// A snippet file with a module comment. Line 8 is indented.
const snippet_source = "//// An example snippet.

import gleam/io

pub const answer = 42

pub fn main() {
  io.println(\"hi\")
}
"

const badge_end = "\"><img align=\"right\" alt=\"Tested snippet\" src=\"https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square\"></a>"

const diff_badge_end = "\"><img align=\"right\" alt=\"Tested diff\" src=\"https://img.shields.io/badge/%F0%9F%A7%AA_tested-diff-lightgreen.svg?style=flat-square\"></a>"

/// The only file with a diff in the fake history: it changed between the
/// tag 2.4.1 and the working tree.
const diff_path = "src/app.gleam"

/// The fake output of `git diff 2.4.1 -- src/app.gleam`.
const fake_diff = "diff --git a/src/app.gleam b/src/app.gleam
index 1111111..2222222 100644
--- a/src/app.gleam
+++ b/src/app.gleam
@@ -1,4 +1,4 @@
 import gleam/io
-import gleam/option.{None, Some}
+import dream/http/request.{Stream}
 import gleam/yielder
@@ -10,5 +10,5 @@ pub fn upload(
 pub fn upload(request) {
-  case request.stream {
-    Some(chunks) -> save(chunks)
+  case request.body {
+    Stream(chunks) -> save(chunks)
   }
"

fn context() -> docs_snippet_check.CheckContext {
  let files = [#(snippet_path, snippet_source)]
  CheckContext(
    version: "3.0.0",
    read_source: fn(path) {
      list.key_find(files, path) |> result.replace_error(simplifile.Enoent)
    },
    tag_exists: fn(tag) { Ok(tag == "2.4.1") },
    diff_from_tag: fake_diff_from_tag,
  )
}

fn fake_diff_from_tag(
  tag: String,
  path: String,
) -> Result(String, docs_snippet_check.GitError) {
  case tag, path {
    "2.4.1", "src/app.gleam" -> Ok(fake_diff)
    _, _ -> Ok("")
  }
}

/// A heading with a badge that links to `target` (a path and an optional
/// anchor) at the tag 3.0.0.
fn heading(target: String) -> String {
  "### Example <a href=\"https://github.com/TrustBound/dream/blob/3.0.0/"
  <> target
  <> badge_end
}

/// A heading with a diff badge that links to the compare view `range`, at
/// the anchor of `path`.
fn diff_heading(range: String, path: String) -> String {
  "### Change <a href=\"https://github.com/TrustBound/dream/compare/"
  <> range
  <> "#diff-"
  <> docs_snippet_check.path_digest(path)
  <> diff_badge_end
}

/// A diff block under `heading_line`. The heading is line 1, the fence
/// line 3, and the `body` lines start at line 4.
fn diff_document(heading_line: String, body: List(String)) -> List(String) {
  list.flatten([[heading_line, "", "```diff"], body, ["```"]])
}

fn diff_file_header(path: String) -> List(String) {
  ["--- a/" <> path, "+++ b/" <> path]
}

fn document(lines: List(String)) -> String {
  string.join(lines, "\n") <> "\n"
}

fn check(lines: List(String)) -> docs_snippet_check.Report {
  docs_snippet_check.check_markdown("doc.md", document(lines), context())
}

fn main_function() -> List(String) {
  ["pub fn main() {", "  io.println(\"hi\")", "}"]
}

pub fn tests() -> UnitTest {
  describe("docs_snippet_check", [
    passing_tests(),
    failing_tests(),
    diff_passing_tests(),
    diff_failing_tests(),
    scope_tests(),
    report_tests(),
    real_git_tests(),
  ])
}

fn passing_tests() -> UnitTest {
  describe("passes", [
    it("a whole-file block with its module comment", fn() {
      // Arrange
      let lines =
        list.flatten([
          [heading(snippet_path), "", "```gleam"],
          string.split(string.drop_end(snippet_source, 1), "\n"),
          ["```"],
        ])

      // Act
      let report = check(lines)

      // Assert
      report
      |> should()
      |> equal(Report(blocks_checked: 1, diff_blocks_checked: 0, problems: []))
      |> or_fail_with("A whole-file block should pass")
    }),
    it("a whole-file block that leaves out the module comment", fn() {
      // Arrange
      let lines =
        list.flatten([
          [heading(snippet_path), "", "```gleam"],
          ["import gleam/io", "", "pub const answer = 42", ""],
          main_function(),
          ["```"],
        ])

      // Act
      let report = check(lines)

      // Assert
      report
      |> should()
      |> equal(Report(blocks_checked: 1, diff_blocks_checked: 0, problems: []))
      |> or_fail_with("A block without the module comment should pass")
    }),
    it("a line-range block", fn() {
      // Arrange
      let lines =
        list.flatten([
          [heading(snippet_path <> "#L7-L9"), "", "```gleam"],
          main_function(),
          ["```"],
        ])

      // Act
      let report = check(lines)

      // Assert
      report
      |> should()
      |> equal(Report(blocks_checked: 1, diff_blocks_checked: 0, problems: []))
      |> or_fail_with("A #L7-L9 block should pass")
    }),
    it("a single-line block with its indent", fn() {
      // Arrange
      let lines = [
        heading(snippet_path <> "#L8"),
        "```gleam",
        "  io.println(\"hi\")",
        "```",
      ]

      // Act
      let report = check(lines)

      // Assert
      report
      |> should()
      |> equal(Report(blocks_checked: 1, diff_blocks_checked: 0, problems: []))
      |> or_fail_with("A #L8 block should pass")
    }),
    it("a block in a /// doc comment", fn() {
      // Arrange
      let source =
        document([
          "/// Runs the example.",
          "///",
          "/// " <> heading(snippet_path <> "#L7-L9"),
          "///",
          "/// ```gleam",
          "/// pub fn main() {",
          "///   io.println(\"hi\")",
          "/// }",
          "/// ```",
          "pub fn run() {",
          "  Nil",
          "}",
        ])

      // Act
      let report =
        docs_snippet_check.check_gleam_source("src/a.gleam", source, context())

      // Assert
      report
      |> should()
      |> equal(Report(blocks_checked: 1, diff_blocks_checked: 0, problems: []))
      |> or_fail_with("A /// doc comment block should pass")
    }),
    it("a block in a //// module comment", fn() {
      // Arrange
      let source =
        document([
          "//// " <> heading(snippet_path <> "#L5"),
          "////",
          "//// ```gleam",
          "//// pub const answer = 42",
          "//// ```",
          "",
          "pub const zero = 0",
        ])

      // Act
      let report =
        docs_snippet_check.check_gleam_source("src/a.gleam", source, context())

      // Assert
      report
      |> should()
      |> equal(Report(blocks_checked: 1, diff_blocks_checked: 0, problems: []))
      |> or_fail_with("A //// module comment block should pass")
    }),
    it("a block in an indented doc comment", fn() {
      // Arrange
      let source =
        document([
          "pub type Example {",
          "  /// " <> heading(snippet_path <> "#L7-L9"),
          "  ///",
          "  /// ```gleam",
          "  /// pub fn main() {",
          "  ///   io.println(\"hi\")",
          "  /// }",
          "  /// ```",
          "  Example",
          "}",
        ])

      // Act
      let report =
        docs_snippet_check.check_gleam_source("src/a.gleam", source, context())

      // Assert
      report
      |> should()
      |> equal(Report(blocks_checked: 1, diff_blocks_checked: 0, problems: []))
      |> or_fail_with("An indented doc comment block should pass")
    }),
    it("a gleam block inside a ````markdown example", fn() {
      // Arrange
      let lines =
        list.flatten([
          ["````markdown", "Some prose.", "", heading(snippet_path <> "#L7-L9")],
          ["", "```gleam"],
          main_function(),
          ["```", "````"],
        ])

      // Act
      let report = check(lines)

      // Assert
      report
      |> should()
      |> equal(Report(blocks_checked: 1, diff_blocks_checked: 0, problems: []))
      |> or_fail_with("A tested block inside a markdown example should pass")
    }),
    it("shell, JavaScript, Elixir and TOML fences", fn() {
      // Arrange
      let lines = [
        "```bash", "gleam run -m docs_snippet_check", "make check | tee log",
        "```", "```javascript", "import { x } from \"./a/b.js\";",
        "let total = 1;", "```", "```elixir", "Enum.map(list, fn x -> x end)",
        "|> Enum.sum()", "```", "```toml", "[dependencies]",
        "dream = \">= 3.0.0\"", "```", "```", "type User = { id: number }",
        "```",
      ]

      // Act
      let report = check(lines)

      // Assert
      report
      |> should()
      |> equal(Report(blocks_checked: 0, diff_blocks_checked: 0, problems: []))
      |> or_fail_with("Fences in other languages should pass")
    }),
  ])
}

fn failing_tests() -> UnitTest {
  describe("fails", [
    it("a gleam block with no heading above", fn() {
      // Arrange
      let lines =
        list.flatten([["Some prose.", "", "```gleam"], main_function(), ["```"]])

      // Act
      let report = check(lines)

      // Assert
      report.problems
      |> should()
      |> equal([Problem("doc.md", 3, MissingBadgeHeading)])
      |> or_fail_with("A block with no heading should fail")
    }),
    it("a heading with two blank lines before the block", fn() {
      // Arrange
      let lines =
        list.flatten([
          [heading(snippet_path <> "#L7-L9"), "", "", "```gleam"],
          main_function(),
          ["```"],
        ])

      // Act
      let report = check(lines)

      // Assert
      report.problems
      |> should()
      |> equal([Problem("doc.md", 4, MissingBadgeHeading)])
      |> or_fail_with("Only one blank line is allowed")
    }),
    it("a badge that is not in the exact format", fn() {
      // Arrange
      let malformed =
        string.replace(
          heading(snippet_path <> "#L7-L9"),
          "alt=\"Tested snippet\"",
          "alt=\"Tested Snippet\"",
        )
      let lines =
        list.flatten([[malformed, "```gleam"], main_function(), ["```"]])

      // Act
      let report = check(lines)

      // Assert
      report.problems
      |> should()
      |> equal([Problem("doc.md", 2, MalformedBadge)])
      |> or_fail_with("A badge with other alt text should fail")
    }),
    it("a badge that links to another repository", fn() {
      // Arrange
      let url =
        "https://github.com/someone/dream/blob/3.0.0/test/snippets/example.gleam"
      let lines =
        list.flatten([
          ["### Example <a href=\"" <> url <> badge_end, "```gleam"],
          main_function(),
          ["```"],
        ])

      // Act
      let report = check(lines)

      // Assert
      report.problems
      |> should()
      |> equal([Problem("doc.md", 2, ForeignLink(url))])
      |> or_fail_with("A link to another repository should fail")
    }),
    it("a badge with a tag that is not the gleam.toml version", fn() {
      // Arrange
      let old_tag =
        string.replace(heading(snippet_path <> "#L7-L9"), "/3.0.0/", "/2.5.0/")
      let lines =
        list.flatten([[old_tag, "```gleam"], main_function(), ["```"]])

      // Act
      let report = check(lines)

      // Assert
      report.problems
      |> should()
      |> equal([
        Problem("doc.md", 2, WrongTag(found: "2.5.0", expected: "3.0.0")),
      ])
      |> or_fail_with("A link at tag 2.5.0 should fail")
    }),
    it("a badge that links to a file that does not exist", fn() {
      // Arrange
      let lines =
        list.flatten([
          [heading("test/snippets/missing.gleam"), "```gleam"],
          main_function(),
          ["```"],
        ])

      // Act
      let report = check(lines)

      // Assert
      report.problems
      |> should()
      |> equal([
        Problem("doc.md", 2, MissingFile("test/snippets/missing.gleam")),
      ])
      |> or_fail_with("A link to a missing file should fail")
    }),
    it("a malformed line range", fn() {
      // Arrange
      let lines =
        list.flatten([
          [heading(snippet_path <> "#L7-9"), "```gleam"],
          main_function(),
          ["```"],
        ])

      // Act
      let report = check(lines)

      // Assert
      report.problems
      |> should()
      |> equal([Problem("doc.md", 2, MalformedLineRange("#L7-9"))])
      |> or_fail_with("#L7-9 should fail")
    }),
    it("a reversed line range", fn() {
      // Arrange
      let lines =
        list.flatten([
          [heading(snippet_path <> "#L9-L7"), "```gleam"],
          main_function(),
          ["```"],
        ])

      // Act
      let report = check(lines)

      // Assert
      report.problems
      |> should()
      |> equal([Problem("doc.md", 2, ReversedLineRange(start: 9, end: 7))])
      |> or_fail_with("#L9-L7 should fail")
    }),
    it("a line range past the end of the file", fn() {
      // Arrange
      let lines =
        list.flatten([
          [heading(snippet_path <> "#L7-L11"), "```gleam"],
          main_function(),
          ["```"],
        ])

      // Act
      let report = check(lines)

      // Assert
      report.problems
      |> should()
      |> equal([Problem("doc.md", 2, LineRangePastEnd(end: 11, line_count: 9))])
      |> or_fail_with("#L7-L11 of a 9-line file should fail")
    }),
    it("a block that differs from its line range", fn() {
      // Arrange
      let lines = [
        heading(snippet_path <> "#L7-L9"),
        "```gleam",
        "pub fn main() {",
        "  io.println(\"ho\")",
        "}",
        "```",
      ]

      // Act
      let report = check(lines)

      // Assert
      report.problems
      |> should()
      |> equal([
        Problem(
          "doc.md",
          2,
          BlockDiffers(
            path: snippet_path,
            anchor: "#L7-L9",
            first_difference_line: 4,
          ),
        ),
      ])
      |> or_fail_with("A changed character should fail")
    }),
    it("a block with a changed indent", fn() {
      // Arrange
      let lines = [
        heading(snippet_path <> "#L8"),
        "```gleam",
        "io.println(\"hi\")",
        "```",
      ]

      // Act
      let report = check(lines)

      // Assert
      report.problems
      |> should()
      |> equal([
        Problem(
          "doc.md",
          2,
          BlockDiffers(
            path: snippet_path,
            anchor: "#L8",
            first_difference_line: 3,
          ),
        ),
      ])
      |> or_fail_with("A block with no indent should fail")
    }),
    it("a whole-file block that misses the last line", fn() {
      // Arrange
      let lines =
        list.flatten([
          [heading(snippet_path), "```gleam"],
          ["import gleam/io", "", "pub const answer = 42", ""],
          ["pub fn main() {", "  io.println(\"hi\")"],
          ["```"],
        ])

      // Act
      let report = check(lines)

      // Assert
      report.problems
      |> should()
      |> equal([
        Problem(
          "doc.md",
          2,
          BlockDiffers(path: snippet_path, anchor: "", first_difference_line: 9),
        ),
      ])
      |> or_fail_with("A whole-file block with a missing line should fail")
    }),
    it("a block with the old Tested source line", fn() {
      // Arrange
      let lines =
        list.flatten([
          ["## Example", "", "Prose.", "", "```gleam"],
          main_function(),
          ["```", "<sub>🧪 [Tested source](test/snippets/example.gleam)</sub>"],
        ])

      // Act
      let report = check(lines)

      // Assert
      report.problems
      |> should()
      |> equal([
        Problem("doc.md", 5, MissingBadgeHeading),
        Problem("doc.md", 10, OldTestedSourceLine),
      ])
      |> or_fail_with("The old Tested source form should fail")
    }),
    it("Gleam code in a text fence", fn() {
      // Arrange
      let lines =
        list.flatten([["Prose.", "", "```text"], main_function(), ["```"]])

      // Act
      let report = check(lines)

      // Assert
      report.problems
      |> should()
      |> equal([Problem("doc.md", 4, HiddenGleamCode("text"))])
      |> or_fail_with("Gleam code in a text fence should fail")
    }),
    it("Gleam code in a fence with no language", fn() {
      // Arrange
      let lines = ["```", "import dream/http.{type Request}", "```"]

      // Act
      let report = check(lines)

      // Assert
      report.problems
      |> should()
      |> equal([Problem("doc.md", 2, HiddenGleamCode(""))])
      |> or_fail_with("Gleam code in a bare fence should fail")
    }),
    it("an untested gleam block inside a ````markdown example", fn() {
      // Arrange
      let lines =
        list.flatten([
          ["````markdown", "## Example", "", "```gleam"],
          main_function(),
          ["```", "````"],
        ])

      // Act
      let report = check(lines)

      // Assert
      report.problems
      |> should()
      |> equal([Problem("doc.md", 4, MissingBadgeHeading)])
      |> or_fail_with("A block inside a markdown example should be checked")
    }),
  ])
}

fn report_tests() -> UnitTest {
  describe("reports", [
    it("every problem in every file, sorted by file and line", fn() {
      // Arrange
      let second =
        check(
          list.flatten([
            ["```text", "use x <- result.try(y)", "```", "```gleam"],
            main_function(),
            ["```"],
          ]),
        )
      let first =
        docs_snippet_check.check_markdown(
          "a.md",
          document(["```gleam", "x", "```", "```gleam", "y", "```"]),
          context(),
        )
      let problems = list.append(second.problems, first.problems)

      // Act
      let sorted = docs_snippet_check.sort_problems(problems)

      // Assert
      sorted
      |> should()
      |> equal([
        Problem("a.md", 1, MissingBadgeHeading),
        Problem("a.md", 4, MissingBadgeHeading),
        Problem("doc.md", 2, HiddenGleamCode("text")),
        Problem("doc.md", 4, MissingBadgeHeading),
      ])
      |> or_fail_with("All problems should be reported, sorted")
    }),
    it("describes a problem as file:line: reason", fn() {
      // Arrange
      let problem =
        Problem("docs/a.md", 12, WrongTag(found: "2.5.0", expected: "3.0.0"))

      // Act
      let line = docs_snippet_check.describe_problem(problem)

      // Assert
      line
      |> should()
      |> equal(
        "docs/a.md:12: the badge link uses the tag 2.5.0, but the version in gleam.toml is 3.0.0",
      )
      |> or_fail_with("The problem line should name file, line and reason")
    }),
    it("writes the summary line", fn() {
      // Arrange
      let blocks = 509

      // Act
      let line = docs_snippet_check.summary(blocks, 5, 84, 2)

      // Assert
      line
      |> should()
      |> equal("509 blocks and 5 diff blocks checked in 84 files, 2 problems")
      |> or_fail_with("The summary should count blocks, files and problems")
    }),
    it("reads the version from gleam.toml", fn() {
      // Arrange
      let gleam_toml =
        "name = \"dream\"\nversion = \"3.0.0\"\n\n[dependencies]\nversion = \"9\"\n"

      // Act
      let version = docs_snippet_check.parse_version(gleam_toml)

      // Assert
      version
      |> should()
      |> equal(Ok("3.0.0"))
      |> or_fail_with("The version should come from the top of gleam.toml")
    }),
  ])
}

fn diff_report(body: List(String)) -> docs_snippet_check.Report {
  check(diff_document(diff_heading("2.4.1...3.0.0", diff_path), body))
}

fn diff_problems(body: List(String)) -> List(docs_snippet_check.Problem) {
  diff_report(body).problems
}

fn diff_passing_tests() -> UnitTest {
  describe("passes a diff block", [
    it("with no hunk header, as a run of lines inside one hunk", fn() {
      // Arrange
      let body =
        list.append(diff_file_header(diff_path), [
          "-  case request.stream {",
          "-    Some(chunks) -> save(chunks)",
          "+  case request.body {",
        ])

      // Act
      let report = diff_report(body)

      // Assert
      report
      |> should()
      |> equal(Report(blocks_checked: 0, diff_blocks_checked: 1, problems: []))
      |> or_fail_with("Real diff lines with no hunk header should pass")
    }),
    it("with hunk headers, one per hunk, in order", fn() {
      // Arrange
      let body =
        list.append(diff_file_header(diff_path), [
          "@@ -1,4 +1,4 @@",
          " import gleam/io",
          "-import gleam/option.{None, Some}",
          "@@ -10,5 +10,5 @@",
          "+    Stream(chunks) -> save(chunks)",
          "   }",
        ])

      // Act
      let report = diff_report(body)

      // Assert
      report
      |> should()
      |> equal(Report(blocks_checked: 0, diff_blocks_checked: 1, problems: []))
      |> or_fail_with(
        "Two hunks with their headers should pass, and the Gleam context line should not count as hidden Gleam code",
      )
    }),
    it("with a hunk header that keeps the function name git adds", fn() {
      // Arrange
      let body =
        list.append(diff_file_header(diff_path), [
          "@@ -10,5 +10,5 @@ pub fn upload(",
          " pub fn upload(request) {",
          "-  case request.stream {",
        ])

      // Act
      let report = diff_report(body)

      // Assert
      report
      |> should()
      |> equal(Report(blocks_checked: 0, diff_blocks_checked: 1, problems: []))
      |> or_fail_with("The full hunk header line should pass")
    }),
  ])
}

fn diff_failing_tests() -> UnitTest {
  let real_lines = ["-  case request.stream {"]
  describe("fails a diff block", [
    it("with no heading", fn() {
      // Arrange
      let lines =
        list.flatten([
          ["```diff"],
          diff_file_header(diff_path),
          real_lines,
          ["```"],
        ])

      // Act
      let report = check(lines)

      // Assert
      report.problems
      |> should()
      |> equal([Problem("doc.md", 1, MissingDiffBadgeHeading)])
      |> or_fail_with("A diff block with no badge should fail")
    }),
    it("with a badge that is not in the exact format", fn() {
      // Arrange
      let heading_line =
        string.replace(
          diff_heading("2.4.1...3.0.0", diff_path),
          "flat-square",
          "flat",
        )

      // Act
      let report =
        check(diff_document(
          heading_line,
          list.append(diff_file_header(diff_path), real_lines),
        ))

      // Assert
      report.problems
      |> should()
      |> equal([Problem("doc.md", 3, MalformedDiffBadge)])
      |> or_fail_with("A changed diff badge should fail")
    }),
    it("with a link that is not a compare link in this repository", fn() {
      // Arrange
      let heading_line =
        string.replace(
          diff_heading("2.4.1...3.0.0", diff_path),
          "TrustBound/dream/compare",
          "someone/dream/compare",
        )
      let address =
        "https://github.com/someone/dream/compare/2.4.1...3.0.0#diff-"
        <> docs_snippet_check.path_digest(diff_path)

      // Act
      let report =
        check(diff_document(
          heading_line,
          list.append(diff_file_header(diff_path), real_lines),
        ))

      // Assert
      report.problems
      |> should()
      |> equal([Problem("doc.md", 3, NotCompareLink(address))])
      |> or_fail_with("A compare link to another repository should fail")
    }),
    it("with a new tag that is not the gleam.toml version", fn() {
      // Arrange
      let heading_line = diff_heading("2.4.1...2.9.0", diff_path)

      // Act
      let report =
        check(diff_document(
          heading_line,
          list.append(diff_file_header(diff_path), real_lines),
        ))

      // Assert
      report.problems
      |> should()
      |> equal([
        Problem("doc.md", 3, WrongNewTag(found: "2.9.0", expected: "3.0.0")),
      ])
      |> or_fail_with("A new tag other than 3.0.0 should fail")
    }),
    it("with an old tag that is not in the clone", fn() {
      // Arrange
      let heading_line = diff_heading("1.9.9...3.0.0", diff_path)

      // Act
      let report =
        check(diff_document(
          heading_line,
          list.append(diff_file_header(diff_path), real_lines),
        ))

      // Assert
      report.problems
      |> should()
      |> equal([Problem("doc.md", 3, MissingOldTag("1.9.9"))])
      |> or_fail_with("A missing old tag should fail")
    }),
    it("with an anchor that is not the digest of its path", fn() {
      // Arrange
      let heading_line = diff_heading("2.4.1...3.0.0", "src/other.gleam")
      let expected = "#diff-" <> docs_snippet_check.path_digest(diff_path)

      // Act
      let report =
        check(diff_document(
          heading_line,
          list.append(diff_file_header(diff_path), real_lines),
        ))

      // Assert
      report.problems
      |> should()
      |> equal([
        Problem("doc.md", 3, WrongDiffAnchor(path: diff_path, expected:)),
      ])
      |> or_fail_with("An anchor for another path should fail")
    }),
    it("with no --- and +++ file header", fn() {
      // Arrange
      let body = ["-import gleam/option.{None, Some}", "+import gleam/string"]

      // Act
      let problems = diff_problems(body)

      // Assert
      problems
      |> should()
      |> equal([Problem("doc.md", 3, MissingDiffFileHeader)])
      |> or_fail_with("A block with no file header should fail")
    }),
    it("with a path that has characters git must not get", fn() {
      // Arrange
      let path = "src/$(touch x).gleam"
      let heading_line = diff_heading("2.4.1...3.0.0", path)

      // Act
      let report =
        check(diff_document(
          heading_line,
          list.append(diff_file_header(path), real_lines),
        ))

      // Assert
      report.problems
      |> should()
      |> equal([Problem("doc.md", 3, MissingDiffFileHeader)])
      |> or_fail_with("An unsafe path should fail before git runs")
    }),
    it("with a file header and no diff lines", fn() {
      // Arrange
      let body = diff_file_header(diff_path)

      // Act
      let problems = diff_problems(body)

      // Assert
      problems
      |> should()
      |> equal([Problem("doc.md", 3, EmptyDiffBlock)])
      |> or_fail_with("A block with only a file header should fail")
    }),
    it("for a file with no diff since the old tag", fn() {
      // Arrange
      let path = "src/same.gleam"
      let heading_line = diff_heading("2.4.1...3.0.0", path)

      // Act
      let report =
        check(diff_document(
          heading_line,
          list.append(diff_file_header(path), real_lines),
        ))

      // Assert
      report.problems
      |> should()
      |> equal([
        Problem("doc.md", 3, NoDiffForPath(path:, old_tag: "2.4.1")),
      ])
      |> or_fail_with("A file with no changes should fail")
    }),
    it("with a line that is not in the real diff", fn() {
      // Arrange
      let body =
        list.append(diff_file_header(diff_path), [
          "-  case request.stream {",
          "-    Some(chunks) -> keep(chunks)",
        ])

      // Act
      let problems = diff_problems(body)

      // Assert
      problems
      |> should()
      |> equal([
        Problem(
          "doc.md",
          7,
          DiffLineNotFound(path: diff_path, old_tag: "2.4.1"),
        ),
      ])
      |> or_fail_with("A made-up line should fail at that line")
    }),
    it("with lines from two hunks and no header between them", fn() {
      // Arrange
      let body =
        list.append(diff_file_header(diff_path), [
          " import gleam/yielder",
          " pub fn upload(request) {",
        ])

      // Act
      let problems = diff_problems(body)

      // Assert
      problems
      |> should()
      |> equal([
        Problem(
          "doc.md",
          7,
          DiffLineNotFound(path: diff_path, old_tag: "2.4.1"),
        ),
      ])
      |> or_fail_with("Lines that are not contiguous in one hunk should fail")
    }),
    it("with a hunk header that is not in the real diff", fn() {
      // Arrange
      let body =
        list.append(diff_file_header(diff_path), [
          "@@ -10,6 +10,5 @@",
          "-  case request.stream {",
        ])

      // Act
      let problems = diff_problems(body)

      // Assert
      problems
      |> should()
      |> equal([
        Problem("doc.md", 6, HunkHeaderNotFound("@@ -10,6 +10,5 @@")),
      ])
      |> or_fail_with("A wrong hunk header should fail")
    }),
    it("when git cannot run", fn() {
      // Arrange
      let no_git =
        CheckContext(
          ..context(),
          tag_exists: fn(_tag) { Error(GitNotFound) },
          diff_from_tag: fn(_tag, _path) { Error(GitNotFound) },
        )
      let lines =
        diff_document(
          diff_heading("2.4.1...3.0.0", diff_path),
          list.append(diff_file_header(diff_path), real_lines),
        )

      // Act
      let report =
        docs_snippet_check.check_markdown("doc.md", document(lines), no_git)

      // Assert
      report.problems
      |> should()
      |> equal([Problem("doc.md", 3, GitUnavailable(GitNotFound))])
      |> or_fail_with("A missing git should be a problem, not a crash")
    }),
  ])
}

fn scope_tests() -> UnitTest {
  describe("scope", [
    it("reads the version from a release notes file name", fn() {
      // Arrange
      let path = "releases/release-2.4.1.md"

      // Act
      let version = docs_snippet_check.release_notes_version(path)

      // Assert
      version
      |> should()
      |> equal(Ok(Version(2, 4, 1)))
      |> or_fail_with("The version should come from the file name")
    }),
    it("skips release notes before 3.0.0", fn() {
      // Arrange
      let paths = [
        "releases/release-2.4.1.md", "releases/release-0.1.0.md",
        "releases/notes.md",
      ]

      // Act
      let checked = list.map(paths, docs_snippet_check.is_checked_release_notes)

      // Assert
      checked
      |> should()
      |> equal([False, False, False])
      |> or_fail_with("Older or unversioned release notes should be skipped")
    }),
    it("checks release notes at and after 3.0.0, compared as numbers", fn() {
      // Arrange
      let paths = [
        "releases/release-3.0.0.md", "releases/release-3.1.0.md",
        "releases/release-10.0.0.md",
      ]

      // Act
      let checked = list.map(paths, docs_snippet_check.is_checked_release_notes)

      // Assert
      checked
      |> should()
      |> equal([True, True, True])
      |> or_fail_with("Release notes from 3.0.0 on should be checked")
    }),
    it("checks only the changelog sections from 3.0.0 on", fn() {
      // Arrange
      let untested_block = ["```gleam", "x", "```"]
      let text =
        document(
          list.flatten([
            ["# Changelog", "", "## [Unreleased]"],
            untested_block,
            ["## [3.0.0] - Unreleased"],
            untested_block,
            ["## [2.4.1] - 2026-03-11"],
            untested_block,
            ["## [1.0.0] - 2025-11-21"],
            untested_block,
          ]),
        )

      // Act
      let report =
        docs_snippet_check.check_changelog("CHANGELOG.md", text, context())

      // Assert
      report.problems
      |> should()
      |> equal([
        Problem("CHANGELOG.md", 4, MissingBadgeHeading),
        Problem("CHANGELOG.md", 8, MissingBadgeHeading),
      ])
      |> or_fail_with("Only [Unreleased] and [3.0.0] should be checked")
    }),
  ])
}

fn real_git_tests() -> UnitTest {
  describe("real git and digest", [
    it("finds the tag 2.4.1 and not a tag that does not exist", fn() {
      // Arrange
      let tags = ["2.4.1", "0.0.0-not-a-tag"]

      // Act
      let found = list.map(tags, docs_snippet_check.git_tag_exists)

      // Assert
      found
      |> should()
      |> equal([Ok(True), Ok(False)])
      |> or_fail_with("git should find 2.4.1 (run git fetch --tags if not)")
    }),
    it("uses the anchor GitHub gives CHANGELOG.md in a compare view", fn() {
      // Arrange
      let path = "CHANGELOG.md"

      // Act
      let digest = docs_snippet_check.path_digest(path)

      // Assert
      digest
      |> should()
      |> equal(
        "06572a96a58dc510037d5efa622f9bec8519bc1beab13c9f251e97e657a9d4ed",
      )
      |> or_fail_with("The anchor should be the SHA-256 digest of the path")
    }),
  ])
}
