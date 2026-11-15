//// Tests for the docs_snippet_check module, which fails when a Gleam code
//// block in the docs is not backed by tested code.
////
//// Each fixture is a small inline document. The linked snippet files are
//// held in a list, so the tests never read the real docs or snippets.

import docs_snippet_check.{
  BlockDiffers, CheckContext, ForeignLink, HiddenGleamCode, LineRangePastEnd,
  MalformedBadge, MalformedLineRange, MissingBadgeHeading, MissingFile,
  OldTestedSourceLine, Problem, Report, ReversedLineRange, WrongTag,
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

fn context() -> docs_snippet_check.CheckContext {
  let files = [#(snippet_path, snippet_source)]
  CheckContext(version: "3.0.0", read_source: fn(path) {
    list.key_find(files, path) |> result.replace_error(simplifile.Enoent)
  })
}

/// A heading with a badge that links to `target` (a path and an optional
/// anchor) at the tag 3.0.0.
fn heading(target: String) -> String {
  "### Example <a href=\"https://github.com/TrustBound/dream/blob/3.0.0/"
  <> target
  <> badge_end
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
    report_tests(),
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
      |> equal(Report(blocks_checked: 1, problems: []))
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
      |> equal(Report(blocks_checked: 1, problems: []))
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
      |> equal(Report(blocks_checked: 1, problems: []))
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
      |> equal(Report(blocks_checked: 1, problems: []))
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
      |> equal(Report(blocks_checked: 1, problems: []))
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
      |> equal(Report(blocks_checked: 1, problems: []))
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
      |> equal(Report(blocks_checked: 1, problems: []))
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
      |> equal(Report(blocks_checked: 1, problems: []))
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
      |> equal(Report(blocks_checked: 0, problems: []))
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
      let line = docs_snippet_check.summary(blocks, 84, 2)

      // Assert
      line
      |> should()
      |> equal("509 blocks checked in 84 files, 2 problems")
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
