# outbound_http

A small Dream app that calls a forecast service from its controllers. The guide [Call another API from a controller](https://hexdocs.pm/dream/3.0.0/guides/calling-other-apis.html) explains the code.

The files:

- `src/forecast_service.gleam`: the client module of the forecast service. Each function returns a `Result` with a `ForecastError`.
- `src/services.gleam`: the base request of the service, built one time.
- `src/controllers/forecasts_controller.gleam`: the controllers, and the status for each error (`404`, `502`, `504`).
- `test/fake_forecast_service.gleam`: a fake forecast service, a small Dream server on localhost.
- `test/forecasts_tests.gleam`: the tests. They start the fake service on port 19880 and the app on port 19881, and send real HTTP requests to the app.
- `test/outputs`: the answers that the guide shows. A test compares them with the real answers.

`make test` checks the format and runs the tests. It needs no network and no Docker. CI runs it.
