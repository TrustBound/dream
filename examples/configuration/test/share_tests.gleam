//// The share links of the app, tested through its routes. Each test
//// builds a `Configuration` value, so no test reads or changes the
//// environment.

import app_request.{answer, get}
import dream_test/context
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit_context.{describe, it}
import gleam/result
import gleam/uri
import links/configuration.{Configuration}
import links/services.{type Services}
import links/signing_key

pub fn tests() -> TestSuite {
  describe(
    "Share links",
    context.setup(production_site, teardown: no_teardown),
    [
      it("answers a link that starts with the site URL", fn(services) {
        let path = "/items/42/share"

        let response = get(services, path)

        answer(response)
        |> should
        |> be_equal(#(
          200,
          "https://links.example.com/items/42?signature=60dd4d8b4377f41bd80b83661e5778e6515462e9e0229857228c32fcba9f731d",
        ))
        |> or_fail_with("GET " <> path <> " should answer the signed link")
      }),
    ],
  )
}

pub fn local_tests() -> TestSuite {
  describe(
    "Share links on a local site",
    context.setup(local_site, teardown: no_teardown),
    [
      it("answers a link with the host and port of the site URL", fn(services) {
        let path = "/items/42/share"

        let response = get(services, path)

        answer(response)
        |> should
        |> be_equal(#(
          200,
          "http://localhost:4000/items/42?signature=60dd4d8b4377f41bd80b83661e5778e6515462e9e0229857228c32fcba9f731d",
        ))
        |> or_fail_with("GET " <> path <> " should answer the signed link")
      }),
    ],
  )
}

fn production_site() -> Result(Services, String) {
  services_for("https://links.example.com")
}

fn local_site() -> Result(Services, String) {
  services_for("http://localhost:4000")
}

/// The services of a test, made from a `Configuration` value, as `main`
/// makes them. No test reads the environment.
fn services_for(site_url: String) -> Result(Services, String) {
  use site_url <- result.try(
    uri.parse(site_url)
    |> result.replace_error("the site URL of the test is not valid"),
  )
  use key <- result.try(
    signing_key.new("test-signing-key-0123456789abcdef")
    |> result.replace_error("the signing key of the test is too short"),
  )
  Configuration(port: 3000, site_url:, signing_key: key)
  |> services.from_configuration
  |> Ok
}

fn no_teardown(_services: Services) -> Result(Nil, String) {
  Ok(Nil)
}
