//// Tests for the docs_snippet_pages module, which makes the "tested
//// snippet" badge links in the built docs point at local snippet pages.

import docs_snippet_pages.{
  MissingSnippet, RewrittenPage, SnippetLink, SnippetReference,
}
import dream_test/assertions/should.{
  be_none, contain_string, equal, or_fail_with, should,
}
import dream_test/unit.{type UnitTest, describe, it}
import gleam/option.{Some}

const snippet_href = "https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/sse_action_builders.gleam"

fn badge(href: String) -> String {
  "<p><a href=\"" <> href <> "\"><img src=\"badge.svg\"/></a></p>"
}

pub fn tests() -> UnitTest {
  describe("docs_snippet_pages", [
    describe("rewrite_page", [
      it("rewrites a snippet link at depth 0 to snippets/", fn() {
        // Arrange
        let html = badge(snippet_href)

        // Act
        let result = docs_snippet_pages.rewrite_page(html, "index.html")

        // Assert
        result
        |> should()
        |> equal(
          RewrittenPage(
            html: badge("snippets/sse_action_builders.html"),
            snippet_names: ["sse_action_builders"],
          ),
        )
        |> or_fail_with("Expected a root-relative snippet link")
      }),
      it("rewrites a snippet link at depth 3 with three ../", fn() {
        // Arrange
        let html = badge(snippet_href)

        // Act
        let result =
          docs_snippet_pages.rewrite_page(
            html,
            "dream/servers/mist/server.html",
          )

        // Assert
        result.html
        |> should()
        |> equal(badge("../../../snippets/sse_action_builders.html"))
        |> or_fail_with("Expected three ../ segments at depth 3")
      }),
      it("keeps a line range anchor", fn() {
        // Arrange
        let html = badge(snippet_href <> "#L8-L10")

        // Act
        let result = docs_snippet_pages.rewrite_page(html, "index.html")

        // Assert
        result.html
        |> should()
        |> equal(badge("snippets/sse_action_builders.html#L8-L10"))
        |> or_fail_with("Expected the #L8-L10 anchor to stay")
      }),
      it("keeps a single line anchor", fn() {
        // Arrange
        let html = badge(snippet_href <> "#L8")

        // Act
        let result = docs_snippet_pages.rewrite_page(html, "index.html")

        // Assert
        result.html
        |> should()
        |> equal(badge("snippets/sse_action_builders.html#L8"))
        |> or_fail_with("Expected the #L8 anchor to stay")
      }),
      it("leaves a non-snippet GitHub link unchanged", fn() {
        // Arrange
        let html =
          badge(
            "https://github.com/TrustBound/dream/blob/3.0.0/src/dream.gleam",
          )

        // Act
        let result = docs_snippet_pages.rewrite_page(html, "index.html")

        // Assert
        result
        |> should()
        |> equal(RewrittenPage(html:, snippet_names: []))
        |> or_fail_with("Expected the page to stay unchanged")
      }),
      it("rewrites a snippet link with a different tag", fn() {
        // Arrange
        let html =
          badge(
            "https://github.com/TrustBound/dream/blob/2.4.1/test/snippets/sse_event_builders.gleam#L3-L5",
          )

        // Act
        let result = docs_snippet_pages.rewrite_page(html, "dream/http.html")

        // Assert
        result.html
        |> should()
        |> equal(badge("../snippets/sse_event_builders.html#L3-L5"))
        |> or_fail_with("Expected the 2.4.1 link to be rewritten")
      }),
    ]),
    describe("find_snippet_link", [
      it("gives None for a link with an anchor that is not a line", fn() {
        // Arrange
        let href = snippet_href <> "#readme"

        // Act
        let result = docs_snippet_pages.find_snippet_link(href)

        // Assert
        result
        |> should()
        |> be_none()
        |> or_fail_with("Expected no snippet link for a #readme anchor")
      }),
      it("reads the name and anchor of a snippet link", fn() {
        // Arrange
        let href = snippet_href <> "#L3-L5"

        // Act
        let result = docs_snippet_pages.find_snippet_link(href)

        // Assert
        result
        |> should()
        |> equal(
          Some(SnippetLink(name: "sse_action_builders", anchor: "#L3-L5")),
        )
        |> or_fail_with("Expected the snippet name and anchor")
      }),
    ]),
    describe("find_missing_snippet", [
      it("returns MissingSnippet naming the page and file", fn() {
        // Arrange
        let references = [
          SnippetReference(page: "index.html", name: "sse_action_builders"),
          SnippetReference(page: "dream/router.html", name: "no_such_snippet"),
        ]

        // Act
        let result =
          docs_snippet_pages.find_missing_snippet(references, [
            "sse_action_builders",
          ])

        // Assert
        result
        |> should()
        |> equal(
          Error(MissingSnippet(
            page: "dream/router.html",
            snippet_path: "test/snippets/no_such_snippet.gleam",
          )),
        )
        |> or_fail_with("Expected a MissingSnippet error")
      }),
      it("returns Ok when every snippet exists", fn() {
        // Arrange
        let references = [
          SnippetReference(page: "index.html", name: "sse_action_builders"),
        ]

        // Act
        let result =
          docs_snippet_pages.find_missing_snippet(references, [
            "sse_action_builders",
          ])

        // Assert
        result
        |> should()
        |> equal(Ok(Nil))
        |> or_fail_with("Expected Ok when the snippet exists")
      }),
    ]),
    describe("render_snippet_page", [
      it("contains the escaped snippet text", fn() {
        // Arrange
        let source = "let html = \"<b>&</b>\"\n"

        // Act
        let result = docs_snippet_pages.render_snippet_page("example", source)

        // Assert
        result
        |> should()
        |> contain_string(
          "<code>let html = &quot;&lt;b&gt;&amp;&lt;/b&gt;&quot;</code>",
        )
        |> or_fail_with("Expected the snippet text to be escaped")
      }),
      it("gives each line an anchor", fn() {
        // Arrange
        let source = "first\nsecond\n"

        // Act
        let result = docs_snippet_pages.render_snippet_page("example", source)

        // Assert
        result
        |> should()
        |> contain_string(
          "<tr class=\"snippet-line\" id=\"L2\"><td class=\"snippet-line-number\"><a href=\"#L2\">2</a></td><td class=\"snippet-line-code\"><code>second</code></td></tr>",
        )
        |> or_fail_with("Expected an L2 anchor on the second line")
      }),
      it("loads the docs stylesheet relative to snippets/", fn() {
        // Arrange
        let source = "first\n"

        // Act
        let result = docs_snippet_pages.render_snippet_page("example", source)

        // Assert
        result
        |> should()
        |> contain_string("href=\"../css/index.css\"")
        |> or_fail_with("Expected ../css/index.css")
      }),
      it("loads the syntax theme relative to snippets/", fn() {
        // Arrange
        let source = "first\n"

        // Act
        let result = docs_snippet_pages.render_snippet_page("example", source)

        // Assert
        result
        |> should()
        |> contain_string(
          "<link id=\"syntax-theme\" rel=\"stylesheet\" href=\"../css/atom-one-light.min.css\"/>",
        )
        |> or_fail_with("Expected ../css/atom-one-light.min.css")
      }),
      it("loads highlight.js relative to snippets/", fn() {
        // Arrange
        let source = "first\n"

        // Act
        let result = docs_snippet_pages.render_snippet_page("example", source)

        // Assert
        result
        |> should()
        |> contain_string("<script src=\"../js/highlight.min.js\"></script>")
        |> or_fail_with("Expected ../js/highlight.min.js")
      }),
      it("loads the Gleam grammar relative to snippets/", fn() {
        // Arrange
        let source = "first\n"

        // Act
        let result = docs_snippet_pages.render_snippet_page("example", source)

        // Assert
        result
        |> should()
        |> contain_string(
          "<script src=\"../js/highlightjs-gleam.js\"></script>",
        )
        |> or_fail_with("Expected ../js/highlightjs-gleam.js")
      }),
    ]),
  ])
}
