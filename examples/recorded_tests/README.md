# recorded_tests

Two small Dream apps, and tests that play back recorded HTTP calls and recorded queries. Two guides explain the code:

- [Test a Dream app that calls other APIs](https://hexdocs.pm/dream/3.0.0/guides/testing-with-recorded-http.html)
- [Test a Dream app's database code with recorded queries](https://hexdocs.pm/dream/3.0.0/guides/testing-with-recorded-queries.html)

The folders:

- `src/parcels`: an app that asks a carrier API for parcels. The base request of the API is in its services.
- `src/lists`: an app for shopping lists in PostgreSQL. The connection is in its services.
- `test/recorded_http` and `test/recorded_queries`: the suites, and the setup that gives each app services with a recorder.
- `test/recordings`: the committed recordings.
- `test/outputs`: the outputs that the guides show. The tests compare them with the real reports.

`make test` plays back, with no network and no database. CI runs it.

`make record` records again. It starts PostgreSQL in Docker on port 5441. Then it runs the tests with `RECORDER_MODE=record` against a fake carrier API on port 19870. At the end, it removes the container and its data.
