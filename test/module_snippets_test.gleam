//// Tests for the snippets in docs/reference/architecture.md and
//// docs/guides/deployment.md that use the module packages dream_config,
//// dream_json, dream_opensearch and dream_postgres.
////
//// The config tests set environment variables with
//// `fixtures/environment.with_environment`, so they never run at the same
//// time. The OpenSearch tests send requests to the one-shot server in
//// `fixtures/one_shot_http_server`, not to a real OpenSearch. The Postgres
//// tests need no database: they check the config that the snippets make,
//// that the pool starts, and how query results become values.

import dream_opensearch/client as opensearch_client
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{type UnitNode, describe, group, it}
import fixtures/environment.{with_environment}
import fixtures/one_shot_http_server
import gleam/option.{None, Some}
import gleam/result
import pog
import snippets/architecture_config.{AppConfig}
import snippets/architecture_json.{Profile}
import snippets/architecture_opensearch
import snippets/architecture_postgres
import snippets/deployment_guide_config.{Config}
import snippets/deployment_guide_postgres

pub fn tests() -> TestSuite {
  describe("module snippets", [
    architecture_config_tests(),
    architecture_json_tests(),
    architecture_opensearch_tests(),
    architecture_postgres_tests(),
    deployment_config_tests(),
    deployment_postgres_tests(),
  ])
}

// ---------------------------------------------------------------------------
// architecture.md: dream_config
// ---------------------------------------------------------------------------

fn architecture_config_tests() -> UnitNode {
  group("architecture_config.load_config", [
    it("reads DATABASE_URL and PORT", fn() {
      // Arrange
      let variables = [
        #("DATABASE_URL", Some("postgres://localhost/app")),
        #("PORT", Some("8080")),
      ]

      // Act
      let result = with_environment(variables, architecture_config.load_config)

      // Assert
      result
      |> should()
      |> be_equal(
        Ok(AppConfig(database_url: "postgres://localhost/app", port: 8080)),
      )
      |> or_fail_with("load_config should read both values")
    }),
    it("uses port 3000 when PORT is not set", fn() {
      // Arrange
      let variables = [
        #("DATABASE_URL", Some("postgres://localhost/app")),
        #("PORT", None),
      ]

      // Act
      let result = with_environment(variables, architecture_config.load_config)

      // Assert
      result
      |> should()
      |> be_equal(
        Ok(AppConfig(database_url: "postgres://localhost/app", port: 3000)),
      )
      |> or_fail_with("load_config should use port 3000")
    }),
    it("returns an error when DATABASE_URL is not set", fn() {
      // Arrange
      let variables = [#("DATABASE_URL", None), #("PORT", None)]

      // Act
      let result = with_environment(variables, architecture_config.load_config)

      // Assert
      result
      |> should()
      |> be_equal(Error("Required environment variable not set: DATABASE_URL"))
      |> or_fail_with("load_config should name DATABASE_URL")
    }),
  ])
}

// ---------------------------------------------------------------------------
// architecture.md: dream_json
// ---------------------------------------------------------------------------

fn architecture_json_tests() -> UnitNode {
  group("architecture_json.profile_to_json", [
    it("encodes Some as the value and None as null", fn() {
      // Arrange
      let profile = Profile(email: Some("user@example.com"), age: None)

      // Act
      let result = architecture_json.profile_to_json(profile)

      // Assert
      result
      |> should()
      |> be_equal("{\"email\":\"user@example.com\",\"age\":null}")
      |> or_fail_with("Expected the email and a null age")
    }),
    it("encodes an age", fn() {
      // Arrange
      let profile = Profile(email: None, age: Some(36))

      // Act
      let result = architecture_json.profile_to_json(profile)

      // Assert
      result
      |> should()
      |> be_equal("{\"email\":null,\"age\":36}")
      |> or_fail_with("Expected a null email and the age")
    }),
  ])
}

// ---------------------------------------------------------------------------
// architecture.md: dream_opensearch
// ---------------------------------------------------------------------------

fn architecture_opensearch_tests() -> UnitNode {
  group("architecture_opensearch", [
    it("create_client uses localhost 9200", fn() {
      // Arrange
      let opensearch = architecture_opensearch.create_client()

      // Act
      let base_url = opensearch.base_url

      // Assert
      base_url
      |> should()
      |> be_equal("http://localhost:9200")
      |> or_fail_with("create_client should use localhost 9200")
    }),
    it("index_log_entry sends PUT to the document path", fn() {
      // Arrange
      let server = one_shot_http_server.start(201, "{}")
      let opensearch =
        opensearch_client.new(one_shot_http_server.base_url(server))

      // Act
      let _ = architecture_opensearch.index_log_entry(opensearch, "Started")

      // Assert
      one_shot_http_server.await_request(server)
      |> result.map(one_shot_http_server.request_line)
      |> should()
      |> be_equal(Ok(#("PUT", "/logs/_doc/doc-id-123")))
      |> or_fail_with("index_log_entry should send PUT to the document path")
    }),
    it("index_log_entry sends the message as JSON", fn() {
      // Arrange
      let server = one_shot_http_server.start(201, "{}")
      let opensearch =
        opensearch_client.new(one_shot_http_server.base_url(server))

      // Act
      let _ = architecture_opensearch.index_log_entry(opensearch, "Started")

      // Assert
      one_shot_http_server.await_request(server)
      |> result.map(one_shot_http_server.request_body)
      |> should()
      |> be_equal(Ok("{\"message\":\"Started\"}"))
      |> or_fail_with("index_log_entry should send the message as JSON")
    }),
    it("index_log_entry returns the response body", fn() {
      // Arrange
      let server = one_shot_http_server.start(201, "{\"result\":\"created\"}")
      let opensearch =
        opensearch_client.new(one_shot_http_server.base_url(server))

      // Act
      let result =
        architecture_opensearch.index_log_entry(opensearch, "Started")

      // Assert
      result
      |> should()
      |> be_equal(Ok("{\"result\":\"created\"}"))
      |> or_fail_with("index_log_entry should return the response body")
    }),
  ])
}

// ---------------------------------------------------------------------------
// architecture.md: dream_postgres
// ---------------------------------------------------------------------------

fn architecture_postgres_tests() -> UnitNode {
  group("architecture_postgres", [
    it("create_database_config sets the host", fn() {
      // Act
      let config = architecture_postgres.create_database_config()

      // Assert
      config.host
      |> should()
      |> be_equal("localhost")
      |> or_fail_with("Expected host localhost")
    }),
    it("create_database_config sets the database", fn() {
      // Act
      let config = architecture_postgres.create_database_config()

      // Assert
      config.database
      |> should()
      |> be_equal("app")
      |> or_fail_with("Expected database app")
    }),
    it("create_database_config sets the pool size", fn() {
      // Act
      let config = architecture_postgres.create_database_config()

      // Assert
      config.pool_size
      |> should()
      |> be_equal(10)
      |> or_fail_with("Expected pool size 10")
    }),
    // The pool connects in the background, so the pool starts with no
    // database. find_user_name runs a query on a pool, so it is only
    // compiled.
    it("connect_database starts the pool", fn() {
      // Act
      let result = architecture_postgres.connect_database()

      // Assert
      result
      |> result.replace(Nil)
      |> should()
      |> be_equal(Ok(Nil))
      |> or_fail_with("Expected the pool to start")
    }),
    it("describe_user_name returns the name when the result has a row", fn() {
      // Arrange
      let result = Ok(pog.Returned(count: 1, rows: ["Ada"]))

      // Act
      let description = architecture_postgres.describe_user_name(result)

      // Assert
      description
      |> should()
      |> be_equal("Ada")
      |> or_fail_with("Expected Ada")
    }),
    it(
      "describe_user_name returns No such user when the result has no rows",
      fn() {
        // Arrange
        let result = Ok(pog.Returned(count: 0, rows: []))

        // Act
        let description = architecture_postgres.describe_user_name(result)

        // Assert
        description
        |> should()
        |> be_equal("No such user")
        |> or_fail_with("Expected No such user")
      },
    ),
    it(
      "describe_user_name returns a failure message when the query failed",
      fn() {
        // Arrange
        let result = Error(pog.ConnectionUnavailable)

        // Act
        let description = architecture_postgres.describe_user_name(result)

        // Assert
        description
        |> should()
        |> be_equal("The database query failed")
        |> or_fail_with("Expected The database query failed")
      },
    ),
  ])
}

// ---------------------------------------------------------------------------
// deployment.md: config from environment variables
// ---------------------------------------------------------------------------

fn deployment_config_tests() -> UnitNode {
  group("deployment_guide_config.load", [
    it("returns the config when every variable is set", fn() {
      // Arrange
      let variables = [
        #("DATABASE_URL", Some("postgres://localhost/app")),
        #("SECRET_KEY", Some("example-secret-key")),
        #("PORT", Some("8080")),
      ]

      // Act
      let result = with_environment(variables, deployment_guide_config.load)

      // Assert
      result
      |> should()
      |> be_equal(
        Ok(Config(
          database_url: "postgres://localhost/app",
          port: 8080,
          secret_key: "example-secret-key",
        )),
      )
      |> or_fail_with("load should read every value")
    }),
    it("uses port 3000 when PORT is not set", fn() {
      // Arrange
      let variables = [
        #("DATABASE_URL", Some("postgres://localhost/app")),
        #("SECRET_KEY", Some("example-secret-key")),
        #("PORT", None),
      ]

      // Act
      let result = with_environment(variables, deployment_guide_config.load)

      // Assert
      result
      |> should()
      |> be_equal(
        Ok(Config(
          database_url: "postgres://localhost/app",
          port: 3000,
          secret_key: "example-secret-key",
        )),
      )
      |> or_fail_with("load should use port 3000")
    }),
    it("returns an error when PORT is not a number", fn() {
      // Arrange
      let variables = [
        #("DATABASE_URL", Some("postgres://localhost/app")),
        #("SECRET_KEY", Some("example-secret-key")),
        #("PORT", Some("eighty")),
      ]

      // Act
      let result = with_environment(variables, deployment_guide_config.load)

      // Assert
      result
      |> should()
      |> be_equal(Error("PORT must be a number, got: eighty"))
      |> or_fail_with("load should reject PORT=eighty")
    }),
    it("returns an error when DATABASE_URL is not set", fn() {
      // Arrange
      let variables = [
        #("DATABASE_URL", None),
        #("SECRET_KEY", Some("example-secret-key")),
        #("PORT", Some("8080")),
      ]

      // Act
      let result = with_environment(variables, deployment_guide_config.load)

      // Assert
      result
      |> should()
      |> be_equal(Error("DATABASE_URL not set"))
      |> or_fail_with("load should name DATABASE_URL")
    }),
    it("returns an error when SECRET_KEY is not set", fn() {
      // Arrange
      let variables = [
        #("DATABASE_URL", Some("postgres://localhost/app")),
        #("SECRET_KEY", None),
        #("PORT", Some("8080")),
      ]

      // Act
      let result = with_environment(variables, deployment_guide_config.load)

      // Assert
      result
      |> should()
      |> be_equal(Error("SECRET_KEY not set"))
      |> or_fail_with("load should name SECRET_KEY")
    }),
  ])
}

// ---------------------------------------------------------------------------
// deployment.md: pool size
// ---------------------------------------------------------------------------

fn deployment_postgres_tests() -> UnitNode {
  group("deployment_guide_postgres", [
    it("create_database_config sets pool size 15", fn() {
      // Act
      let config = deployment_guide_postgres.create_database_config()

      // Assert
      config.pool_size
      |> should()
      |> be_equal(15)
      |> or_fail_with("Expected pool size 15")
    }),
  ])
}
