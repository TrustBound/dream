# configuration

A small Dream app that reads its settings one time, at startup, and stops with a clear message when a setting is missing or wrong. The guide [Load configuration and fail early](https://hexdocs.pm/dream/3.0.0/guides/configuration.html) explains the code.

The app answers `GET /items/:id/share` with a signed link to an item. It needs three settings:

| Variable | Required | Value |
|:---|:---|:---|
| `SITE_URL` | yes | The http or https address that starts each link, with no path |
| `SIGNING_KEY` | yes | The secret key that signs the links, 32 characters or more |
| `PORT` | no | The port of the server, 3000 when it is not set |

The folders:

- `src/links/configuration.gleam`: reads every setting with [dream_config](https://hexdocs.pm/dream_config/2.0.0/), and gives one `Configuration` value or one error.
- `src/links/main.gleam`: loads the configuration, then starts the server, or prints the error and stops with exit status 1.
- `src/links/services.gleam` and `src/links/share_controller.gleam`: the controller gets the site URL and the key from the services. It never reads the environment.
- `test/share_tests.gleam`: tests through the routes, with a `Configuration` value that each test builds.
- `test/startup_tests.gleam`: runs the app in a new VM with the environment of each test, and compares its output with `test/outputs`.

To run the app, copy `.env.example` to `.env`, then run `make run`. Never commit `.env`.

`make test` checks the format and runs the tests. The tests need no settings, and they do not change the environment of your shell.
