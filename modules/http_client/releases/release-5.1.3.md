# dream_http_client v5.1.3

**Release Date:** March 17, 2026

This patch release fixes a critical bug where concurrent HTTP streams would
silently die when the process that created the shared ETS table exited.
`dream_http_client` is now a proper OTP application — its ETS tables are
owned by the application master process, not by short-lived stream processes.
No API changes.

---

## Bug Fix: ETS table ownership causes silent stream process crashes

### The problem

`dream_httpc_shim` uses two named ETS tables (`dream_http_client_ref_mapping`
and `dream_http_client_stream_recorders`) for runtime state. Three separate
issues combined to produce silent stream failures:

**1. Transient table ownership**

ETS named tables are owned by their creating process. The tables were created
lazily by `ensure_ref_mapping_table()` and `ensure_recorder_table()`, called
from short-lived processes (the caller of `start_stream()`, or the stream
process itself via `request_stream_messages()`). When the creating process
exited, the table was destroyed — taking all ref mappings with it.

**2. Race condition on creation**

If two processes called `ensure_ref_mapping_table()` concurrently when the
table didn't exist, both saw `undefined` from `ets:info/1`, and the second
`ets:new/2` call crashed with `badarg` (named table already exists).

**3. Unprotected ETS access**

Seven functions accessed the ETS table with bare `ets:lookup`/`ets:insert`/
`ets:delete` calls — no error handling. When the table was destroyed, these
threw `badarg` inside `decode_stream_message_for_selector/1`, which runs in
the `receive` block of `gleam_erlang_ffi:select/2`. The crash killed the
stream process, but since it was spawned unlinked (`process.spawn_unlinked`),
no `on_stream_error` callback fired. The stream silently died.

### Observed in production

- Three independent streaming requests hung for exactly 900,001ms (the monitor
  timeout), because the stream process crashed silently and no `on_stream_error`
  callback fired
- Zero crash reports appeared in CloudWatch logs

### The fix: OTP application (the Ranch pattern)

`dream_http_client` is now a proper OTP application. Both ETS tables are
created in the application's `start/2` callback, owned by the application
master process — a long-lived process managed by the BEAM's application
controller that exists for the entire application lifetime.

```erlang
-module(dream_http_client_app).
-behaviour(application).

start(_Type, _Args) ->
    ets:new(dream_http_client_ref_mapping, [set, public, named_table]),
    ets:new(dream_http_client_stream_recorders, [set, public, named_table]),
    dream_http_client_sup:start_link().
```

This is the same pattern used by Ranch (the transport layer behind Cowboy)
for its `ranch_server` ETS table.

**What this eliminates:**

- **Transient ownership.** The application master never exits during normal
  operation. The tables live as long as the application.
- **Race conditions.** Application start is serialized by the BEAM's
  application controller. Two processes cannot race to create the tables.
- **Silent failures.** All `try/catch error:badarg` guards have been removed
  from ETS access functions. If the table somehow doesn't exist (which means
  the application isn't started), the process crashes loudly — visible,
  debuggable, and correct.
- **Unsupervised processes.** The bare `spawn` + `ets:give_away` holder
  process is gone, replaced by OTP's built-in application lifecycle.
- **Lazy table creation.** `ensure_ref_mapping_table/0`,
  `ensure_recorder_table/0`, and `ensure_ets_tables/0` are removed. Tables
  exist from application start, not from first use.

### Regression tests (7 new tests, 192 total)

**ETS ownership verification:**

| Test | What it proves |
|---|---|
| `table_is_owned_by_application_not_caller` | Table exists, owner is not the test process, owner is alive |
| `stored_mappings_survive_writer_process_exit` | Data persists after the writing process exits |

**Integration tests through `start_stream()` API:**

| Test | What it proves |
|---|---|
| `stream_from_expired_caller_completes` | Stream started from a short-lived caller completes after caller exits |
| `concurrent_streams_from_expired_callers_both_complete` | Fast stream (1s) + slow stream (10s) from short-lived callers both complete — the exact bug scenario |
| `three_concurrent_streams_all_complete` | Three concurrent streams don't interfere with each other |
| `sequential_streams_after_process_exit` | New stream works after a previous stream's process has exited |
| `five_concurrent_streams_from_expired_callers` | Stress test: 5 concurrent streams from 5 short-lived callers all complete |

---

## Files changed

- `modules/http_client/src/dream_http_client/dream_http_client_app.erl` — New
  OTP application behaviour module; creates ETS tables in `start/2`
- `modules/http_client/src/dream_http_client/dream_http_client_sup.erl` — New
  minimal supervisor
- `modules/http_client/gleam.toml` — Added `[erlang] application_start_module`
- `modules/http_client/src/dream_http_client/dream_httpc_shim.erl` — Removed
  `ensure_ref_mapping_table/0`, `table_holder_loop/0`, and all `try/catch`
  guards on ETS access; restored direct ETS calls
- `modules/http_client/src/dream_http_client/client.gleam` — Removed lazy
  table creation (`ensure_ets_tables`, `ensure_recorder_table`,
  `ensure_ref_mapping_table_wrapper`, `ets_table_exists`, `ets_new`)
- `modules/http_client/test/ets_table_ownership_test.gleam` — 7 regression
  tests for the new architecture
- `modules/http_client/test/ets_table_ownership_ffi.erl` — Simplified FFI
  helpers for ETS introspection
