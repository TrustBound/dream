# fake_api

A small Dream app that calls a news service, and tests that run it against a fake news service from [`dream_mock_server`](https://hexdocs.pm/dream_mock_server/2.0.0/). The guide [Test a Dream app against a fake API](https://hexdocs.pm/dream/3.0.0/guides/testing-with-a-fake-api.html) explains the code.

The files:

- `src/news_service.gleam`: the client of the news service. Each function takes the request of one feed, and returns a `NewsError`.
- `src/services.gleam`: one request for each feed, built one time.
- `src/controllers/news_controller.gleam`: `GET /headlines` and the streamed `GET /live`, with `502` and `504` for the errors.
- `test/fake_news_service.gleam`: the fake, two mock servers. One on port 19910 gives our own answers, one on port 19911 gives the built-in slow and streamed answers. Nothing listens on port 19912.
- `test/news_tests.gleam`: the tests of the app against each case of the fake.
- `test/contract_tests.gleam`: the contract of the headlines feed, against the fake on port 19913, and against the real service when `NEWS_HEADLINES_URL` is set.
- `test/outputs`: the reports that the guide shows. A test compares them with the real reports.

`make test` checks the format and runs the tests. It needs no network and no Docker. CI runs it. The tests take about 10 seconds, because the mock server holds its slow answer for 5 seconds, and each of the two runs waits for it.
