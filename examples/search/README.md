# search

A small Dream app that keeps notes in a store, and a copy of them in an OpenSearch index. The guide [Add search to a Dream app](https://hexdocs.pm/dream/3.0.0/guides/search.html) explains the code.

The folders:

- `src/notes`: the app. `store.gleam` is the system of record, an actor that keeps the notes in memory. A real app uses its database. `search_index.gleam` creates the index, writes notes to it and searches it. `search_failure.gleam` gives the status for each OpenSearch error.
- `test`: the suites. `search_setup.gleam` gives the app services with a recorder on the base request of the OpenSearch client.
- `test/recordings`: the committed recordings of the OpenSearch calls, one folder for each index.
- `test/outputs`: the outputs that the guide shows. The tests compare them with the real reports.

`make test` plays back, with no network and no OpenSearch. CI runs it.

`make record` records again. It starts OpenSearch 2.19.1 in Docker on port 19200, and runs the tests with `RECORDER_MODE=record`. At the end, it removes the container and its data.

To run the app, start OpenSearch on port 9200, then run `gleam run -m main`. The app listens on port 3000.
