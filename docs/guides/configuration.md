# Load configuration and fail early

An app that runs in more than one place needs settings: the port, the public address of the site, a secret key. The same code runs on your laptop, in CI and in production, and only the settings change. The easy way is to read an environment variable where you need it. That works until a variable is missing. Then the app starts, looks healthy, and fails on the first request that reads the variable, maybe hours later, maybe for one user only. This guide moves every read to one place at startup. The app reads all its settings into one typed value before it opens the port. When a setting is missing or wrong, the app stops at once, prints which setting to fix, and exits with status 1, so that the deployment fails and not the request.

We use [`dream_config`](https://hexdocs.pm/dream_config/2.0.0/) to read the environment and a `.env` file.

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [Step 1: Name every setting in one type](#step-1-name-every-setting-in-one-type)
- [Step 2: Read the settings at startup](#step-2-read-the-settings-at-startup)
- [Step 3: Keep the secret out of sight](#step-3-keep-the-secret-out-of-sight)
- [Step 4: Stop with a clear message](#step-4-stop-with-a-clear-message)
- [Step 5: Use a .env file in development](#step-5-use-a-env-file-in-development)
- [Step 6: Give the values to controllers through services](#step-6-give-the-values-to-controllers-through-services)
- [Step 7: Test without the environment](#step-7-test-without-the-environment)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

The example is a small links app. `GET /items/42/share` answers with a link to item 42 on the public site, with a signature that proves the app made the link. The app needs three settings:

| Variable | Required | Type in the app | Example |
|:---|:---|:---|:---|
| `PORT` | no, 3000 when not set | `Int` from 1 to 65535 | `8080` |
| `SITE_URL` | yes | `Uri` with an http or https scheme and a host | `https://links.example.com` |
| `SIGNING_KEY` | yes, and it is a secret | `SigningKey`, 32 characters or more | (never in a doc) |

In this guide, we will:

- Put every setting in one `Configuration` type, with a type for each value.
- Read the settings one time, in `main`, with `dream_config`, and get one value or one error.
- Stop with a message that names the setting, and exit with status 1.
- Load a `.env` file in development, and let the environment win over it.
- Give the values to the controller through services.
- Test the app with configuration values that the tests make, and test the startup errors in a new VM, so that no test changes the environment.

All the code is in [`examples/configuration`](https://github.com/TrustBound/dream/tree/3.0.0/examples/configuration) of the Dream repository. Its tests compare each output on this page with the real output of the app.

## Before you start

You need a Dream app. If you do not have one, start with [Build your first Dream server](https://hexdocs.pm/dream/3.0.0/guides/getting-started.html). The example adds `dream_config` to read the settings, and `gleam_crypto` to sign the links:

### The dependencies <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/configuration/gleam.toml#L8-L9"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```toml
dream_config = ">= 2.0.0 and < 3.0.0"
gleam_crypto = ">= 1.5.0 and < 2.0.0"
```

## Step 1: Name every setting in one type

Before we read anything, we write down what the app needs. One record holds every setting, with the type that the app uses, not the text that the environment holds:

### The configuration and its errors <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/configuration/src/links/configuration.gleam#L11-L23"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type Configuration {
  Configuration(port: Int, site_url: Uri, signing_key: SigningKey)
}

/// Why the app cannot start. No variant holds the value of a setting, so
/// an error message cannot leak a secret.
pub type ConfigurationError {
  EnvFileInvalid(error: LoadError)
  SettingInvalid(error: ConfigError)
  PortOutOfRange(port: Int)
  SiteUrlInvalid
  SigningKeyTooShort(length: Int)
}
```

The types do work for us. A port is an `Int`, so no code later calls `int.parse`. The site URL is a `Uri`, so the scheme and the host are known to be there. The key is a `SigningKey`, a type that no other module can read (Step 3). When a function gets a `Configuration`, it knows that each value was there and correct at startup.

The error type has one variant for each way that a setting can be wrong. No variant holds the value of a setting. This is on purpose: an error message goes to a log, and the value can be a secret.

## Step 2: Read the settings at startup

`load` reads the settings in order, and stops at the first one that is wrong. Each step is a `use` with `result.try`, so the chain stays flat:

### Load every setting <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/configuration/src/links/configuration.gleam#L28-L35"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Loads `.env` (when the file exists), then reads every setting.
pub fn load() -> Result(Configuration, ConfigurationError) {
  use _ <- result.try(loader.load_dotenv() |> result.map_error(EnvFileInvalid))
  use port <- result.try(read_port())
  use site_url <- result.try(read_site_url())
  use signing_key <- result.try(read_signing_key())
  Ok(Configuration(port:, site_url:, signing_key:))
}
```

`dream_config` has a read function for each case. `get_required` gives `Error(NotSet(name))` for a variable that is not set and `Error(Empty(name))` for an empty one. `get` and `get_int` give `Error(NotSet(name))` for a missing variable, and the caller decides what that means. `get_required_int` and `get_int` give `Error(NotAnInteger(name, value))` for a value that is not a number. `get_bool` gives `False` for a missing variable.

`PORT` is optional, so a missing value is not an error. But a value that is there and wrong is an error. We match the two cases apart:

### Read an optional port <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/configuration/src/links/configuration.gleam#L37-L51"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// `PORT` is optional. When it is set, it must be a port number.
fn read_port() -> Result(Int, ConfigurationError) {
  case loader.get_int("PORT") {
    Ok(port) -> check_port(port)
    Error(loader.NotSet(_)) -> Ok(default_port)
    Error(error) -> Error(SettingInvalid(error))
  }
}

fn check_port(port: Int) -> Result(Int, ConfigurationError) {
  case port >= 1 && port <= 65_535 {
    True -> Ok(port)
    False -> Error(PortOutOfRange(port:))
  }
}
```

This is the important detail of an optional setting. `get_int("PORT") |> result.unwrap(3000)` looks shorter, but it turns `PORT=eighty` into port 3000 with no message. A typo in the deployment then starts the app on the wrong port, and nobody finds out. We use the default only for `NotSet`.

`SITE_URL` is required, and its text must also be a URL that we can use. `gleam/uri` parses it, and a second check makes sure that it has a scheme and a host:

### Read a required URL <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/configuration/src/links/configuration.gleam#L53-L70"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// `SITE_URL` is required: the address that starts each share link.
fn read_site_url() -> Result(Uri, ConfigurationError) {
  use text <- result.try(
    loader.get_required("SITE_URL") |> result.map_error(SettingInvalid),
  )
  uri.parse(text)
  |> result.replace_error(SiteUrlInvalid)
  |> result.try(check_site_url)
}

/// The URL must have an http or https scheme, a host, and no path.
fn check_site_url(site_url: Uri) -> Result(Uri, ConfigurationError) {
  case site_url.scheme, site_url.host, site_url.path {
    Some("https"), Some(_), "" | Some("https"), Some(_), "/" -> Ok(site_url)
    Some("http"), Some(_), "" | Some("http"), Some(_), "/" -> Ok(site_url)
    _, _, _ -> Error(SiteUrlInvalid)
  }
}
```

`uri.parse("links.example.com")` gives `Ok`, with the text as a path and no host. Thus a parse that works is not enough. Each check that the app needs goes here, at startup, and not in the controller.

## Step 3: Keep the secret out of sight

The signing key is a secret. A secret must never go to a log, an error message or a response. A type helps. `SigningKey` is opaque, so code outside its module can sign with the key, but it cannot read the key:

### The signing key <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/configuration/src/links/signing_key.gleam#L8-L36"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub opaque type SigningKey {
  SigningKey(bytes: BitArray)
}

/// A shorter key is too easy to guess.
pub const minimum_length = 32

/// Why a text cannot be a signing key. The error holds the length of the
/// text, never the text.
pub type SigningKeyError {
  TooShort(length: Int)
}

/// The signing key from `text`, when it has `minimum_length` characters or
/// more.
pub fn new(text: String) -> Result(SigningKey, SigningKeyError) {
  let length = string.length(text)
  case length >= minimum_length {
    True -> Ok(SigningKey(bytes: bit_array.from_string(text)))
    False -> Error(TooShort(length:))
  }
}

/// The HMAC-SHA256 signature of `message`, as lowercase hex.
pub fn sign(key: SigningKey, message: String) -> String {
  crypto.hmac(bit_array.from_string(message), crypto.Sha256, key.bytes)
  |> bit_array.base16_encode
  |> string.lowercase
}
```

The error `TooShort` holds the length of the text, not the text. `load` reads the key, and turns that error into a `ConfigurationError`:

### Read the secret <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/configuration/src/links/configuration.gleam#L72-L82"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// `SIGNING_KEY` is required, and it is a secret.
fn read_signing_key() -> Result(SigningKey, ConfigurationError) {
  use text <- result.try(
    loader.get_required("SIGNING_KEY") |> result.map_error(SettingInvalid),
  )
  signing_key.new(text)
  |> result.map_error(fn(error) {
    let TooShort(length:) = error
    SigningKeyTooShort(length:)
  })
}
```

Then we write the two texts that go to the log. `describe_error` names the setting and what is wrong with it. `describe` shows the settings at startup, with `[hidden]` in place of the key:

### The texts for the log <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/configuration/src/links/configuration.gleam#L84-L108"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// The message for an error. It names the setting, never its value.
pub fn describe_error(error: ConfigurationError) -> String {
  case error {
    EnvFileInvalid(error:) -> loader.describe_load_error(error)
    SettingInvalid(error:) -> loader.describe(error)
    PortOutOfRange(port:) ->
      "PORT must be from 1 to 65535, not " <> int.to_string(port)
    SiteUrlInvalid ->
      "SITE_URL must be an http or https URL with a host and no path"
    SigningKeyTooShort(length:) ->
      "SIGNING_KEY must have at least "
      <> int.to_string(signing_key.minimum_length)
      <> " characters, not "
      <> int.to_string(length)
  }
}

/// The settings for the startup log. The signing key shows as `[hidden]`.
pub fn describe(configuration: Configuration) -> String {
  "port: "
  <> int.to_string(configuration.port)
  <> ", site URL: "
  <> uri.to_string(configuration.site_url)
  <> ", signing key: [hidden]"
}
```

`dream_config` does the same for its own errors: the message for `NotAnInteger` names the variable, not the value. The opaque type does not stop every leak. `string.inspect` and `echo` show the bytes inside any value, also an opaque one. Never inspect or echo a `Configuration`, and log it only through `describe`.

## Step 4: Stop with a clear message

`main` loads the configuration before it does anything else. With a configuration, it starts the server. With an error, it prints the message on standard error and stops the VM with exit status 1:

### Start or stop <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/configuration/src/links/main.gleam#L12-L38"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn main() {
  case configuration.load() {
    Ok(settings) -> start(settings)
    Error(error) -> stop(configuration.describe_error(error))
  }
}

fn start(settings: Configuration) {
  io.println("Starting with " <> configuration.describe(settings))
  let assert Ok(Nil) =
    dream.new()
    |> context(EmptyContext)
    |> services(links_services.from_configuration(settings))
    |> router(links_router.create_router())
    |> bind("localhost")
    |> listen(settings.port)
}

/// Prints the reason on standard error, and stops the program with exit
/// status 1, so that the deployment sees the failure.
fn stop(reason: String) -> a {
  io.println_error("The links app cannot start: " <> reason)
  halt(1)
}

@external(erlang, "erlang", "halt")
fn halt(status: Int) -> a
```

`halt` is `erlang:halt/1`. It stops the VM at once, with the status that it gets. The platform that started the app (systemd, Kubernetes, a container runner) sees status 1 and reports a failed start. A missing setting thus stops the deployment, not a request of a user.

Without `SIGNING_KEY`, the app prints this and exits with status 1:

### The output with no SIGNING_KEY <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/configuration/test/outputs/missing_signing_key.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
The links app cannot start: Required environment variable not set: SIGNING_KEY
```

With `PORT=eighty`:

### The output with PORT=eighty <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/configuration/test/outputs/port_not_a_number.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
The links app cannot start: Environment variable PORT must be an integer
```

With `SITE_URL=links.example.com`, which has no scheme:

### The output with no scheme in SITE_URL <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/configuration/test/outputs/site_url_without_scheme.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
The links app cannot start: SITE_URL must be an http or https URL with a host and no path
```

Each message names one variable and what to do with it. None shows a value.

The [BEAM guide](https://hexdocs.pm/dream/3.0.0/guides/beam.html#let-assert-in-request-code) uses `port_setting`, a function that stops the program with `let assert ... as "PORT must be a whole number"`. The rule is the same here: a bad setting is a bug in the deployment, and the program stops at startup. We use a `Result` for the whole configuration, for two reasons. All the settings get one error type, which a test can compare. And a failed `let assert` prints the value that did not match, which for a setting can be a secret. The `let assert Ok(Nil) =` on `listen` stays, as the [operating guide](https://hexdocs.pm/dream/3.0.0/guides/operating.html) explains: its error holds no setting.

## Step 5: Use a .env file in development

In production, the platform sets the environment. On a laptop, it is easier to keep the settings in a file. `load` calls `loader.load_dotenv()` first. It reads `.env` from the current directory and sets each variable that is not already set. A missing file is not an error, so production needs no file. The example commits `.env.example`, and each developer copies it to `.env`:

### The settings for development <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/configuration/.env.example"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```dotenv
# Copy this file to .env for development. Never commit .env.
# The environment wins over the file, so production sets these itself.
PORT=3000
SITE_URL=http://localhost:3000
SIGNING_KEY="development-key-not-for-production"
```

Never commit `.env`. The example's `.gitignore` holds `/.env`, so a real key in a local file stays local.

The environment wins over the file. A value that the platform or your shell sets stays, and the file only fills the gaps. The startup test runs the app in a folder whose `.env` sets `PORT=4322`, with `PORT=4323` in the environment. The app reads the site URL and the key from the file, and the port from the environment:

### The output with a .env file <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/configuration/test/outputs/startup.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Starting with port: 4323, site URL: http://localhost:4322, signing key: [hidden]
```

A line of `.env` that is not valid stops the app as well. `describe_load_error` gives the path and the line number, but not the text of the line, because the line can hold a key:

### The output for a line with no = <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/configuration/test/outputs/invalid_env_file.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
The links app cannot start: Cannot load .env file at .env: line 3: expected NAME=VALUE
```

To let the file win over the environment, `dream_config` has `load_dotenv_override`, and `load_dotenv_from(path)` reads another file. The [`.env` guide of dream_config](https://hexdocs.pm/dream_config/2.0.0/guides/env-files.html) shows the file format and the quote rules.

## Step 6: Give the values to controllers through services

A controller never reads the environment. If it did, a missing variable would fail one request at a time again, and a test would have to change the environment of the whole VM to change it. Instead, `main` makes the services one time from the configuration:

### The services <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/configuration/src/links/services.gleam#L8-L19"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type Services {
  Services(site_url: Uri, signing_key: SigningKey)
}

/// The services of the app. The port is for the server, not for a
/// controller, so the services do not hold it.
pub fn from_configuration(configuration: Configuration) -> Services {
  Services(
    site_url: configuration.site_url,
    signing_key: configuration.signing_key,
  )
}
```

The services hold what the controllers need, and nothing more. The port is for the server, so it stays in `Configuration`. The controller gets the site URL and the key from its `services` parameter:

### The share controller <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/configuration/src/links/share_controller.gleam#L13-L32"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Answers with a signed link to the item. The site URL and the key come
/// from the services, not from the environment.
pub fn share(
  request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  case require_string(request, "id") {
    Ok(id) -> text_response(status.ok, share_link(services, id))
    Error(param_error) ->
      text_response(status.bad_request, error.message(param_error))
  }
}

fn share_link(services: Services, id: String) -> String {
  let path = "/items/" <> id
  let signature = signing_key.sign(services.signing_key, path)
  Uri(..services.site_url, path:, query: Some("signature=" <> signature))
  |> uri.to_string
}
```

The controller cannot get a wrong URL or a short key, because `Services` holds only values that `load` checked. It has no error case for a setting, and no default value.

## Step 7: Test without the environment

The environment belongs to the whole VM, and the tests of `dream_test` run in parallel. A test that sets `SITE_URL` changes it for every other test that runs at the same time. Then the tests fail at random, and they can leak a setting into your shell's next run. The design of Step 6 removes the need. A test makes a `Configuration` value itself, and gives the app the services that `main` makes from it:

### Services from a configuration value <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/configuration/test/share_tests.gleam#L68-L82"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
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
```

Then the test sends a request through the routes, with a site URL that is in the test and nowhere else:

### Test the share link <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/configuration/test/share_tests.gleam#L16-L36"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
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
```

A second suite builds services with `http://localhost:4000`, and gets a link to that host and port. Two configurations, in one test run, in parallel, and no environment variable.

`main` and `load` still read the real environment, and their tests must prove the messages of Step 4. These tests run the app in a new Erlang VM, with an environment that the test gives. The test VM keeps its own environment. The helper removes each setting that a test does not give, so a `SIGNING_KEY` in your shell cannot leak into a test:

### The environment of the new VM <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/configuration/test/startup_ffi.erl#L42-L45"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```erlang
environment(Variables) ->
    Set = [{binary_to_list(Name), binary_to_list(Value)} || {Name, Value} <- Variables],
    Unset = [{Name, false} || Name <- ?settings, not lists:keymember(Name, 1, Set)],
    Unset ++ Set.
```

Each startup test gives the variables, runs the app, and compares the exit status and the output with a file under `test/outputs`. These are the files that this guide shows:

### A startup test <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/configuration/test/startup_tests.gleam#L18-L26"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn tests() -> TestSuite {
  describe("Startup", context.value(valid_settings()), [
    it("stops when SIGNING_KEY is not set", fn(settings) {
      let variables = remove_setting(settings, "SIGNING_KEY")

      let result = run_app(no_env_file, variables)

      result |> stop_with("missing_signing_key")
    }),
```

`make test` in the example runs this script, and the integration job of Dream's CI runs `make test` too. The tests need no settings:

### Run the tests <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/configuration/scripts/test.sh#L6-L7"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```sh
gleam format --check src test
gleam test
```

## Common pitfalls

**A default that hides a wrong value.** *Symptom:* the app listens on port 3000, but the deployment sets `PORT`. *Fix:* use the default only for `NotSet`, as `read_port` does. A value that is set and wrong is an error.

**A setting read in a controller.** *Symptom:* the app starts, and some requests fail with a missing variable. *Fix:* read the setting in `load`, put it in `Configuration`, and give it to the controller through services.

**A secret in a log.** *Symptom:* the startup log or an error message shows a key or a password. *Fix:* keep the value out of every error variant, and log the configuration only through a function such as `describe`. Never `echo` or `string.inspect` a value that holds a secret.

**A committed `.env` file.** *Symptom:* `git status` shows `.env`. *Fix:* add `/.env` to `.gitignore`, commit `.env.example` with values that are not secret, and change any key that was in a commit.

**A test that sets an environment variable.** *Symptom:* tests pass alone and fail together, or they change from run to run. *Fix:* build a `Configuration` value in the test. To test `load` itself, run the app in a new VM with its own environment, as `startup_ffi.erl` does.

**A URL that parses but has no host.** *Symptom:* the links start with `links.example.com/items` and the browser opens a path. *Fix:* check the scheme and the host after `uri.parse`, as `check_site_url` does.

## Where to go next

- [The BEAM for Dream developers](https://hexdocs.pm/dream/3.0.0/guides/beam.html): when `let assert` is right, and why a crash in request code is wrong.
- [Start, stop and troubleshoot the server](https://hexdocs.pm/dream/3.0.0/guides/operating.html): the address, the port and the start errors.
- [Deploy with Docker](https://hexdocs.pm/dream/3.0.0/guides/deployment.html): set the environment of the app in production.
- [Test your controllers and your app](https://hexdocs.pm/dream/3.0.0/guides/testing.html): matchers, fixtures and tests through the routes.
- [Test a Dream app that calls other APIs](https://hexdocs.pm/dream/3.0.0/guides/testing-with-recorded-http.html): services that hold the base request of an API.
- [dream_config](https://hexdocs.pm/dream_config/2.0.0/): the full API, with [optional settings, numbers and flags](https://hexdocs.pm/dream_config/2.0.0/guides/typed-values.html) and [.env files](https://hexdocs.pm/dream_config/2.0.0/guides/env-files.html).
