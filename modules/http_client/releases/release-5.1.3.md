# dream_http_client v5.1.3

**Release Date:** March 17, 2026

This patch release fixes a critical bug where concurrent HTTP streams would
silently die when the process that created the shared ETS table exited. No API
changes — this is a fully transparent bug fix.

---

## Bug Fix: ETS table ownership causes silent stream process crashes

### The problem

`dream_httpc_shim` uses a lazily-created named ETS table
(`dream_http_client_ref_mapping`) for mapping httpc refs to string IDs. Three
separate issues combined to produce silent stream failures:

**1. Transient table ownership**

ETS named tables are owned by their creating process. `ensure_ref_mapping_table()`
was called from short-lived processes (the caller of `start_stream()`, or the
stream process itself via `request_stream_messages()`). When the creating process
exited, the table was destroyed — taking all ref mappings with it.

**2. Race condition on creation**

If two processes called `ensure_ref_mapping_table()` concurrently when the table
didn't exist, both saw `undefined` from `ets:info/1`, and the second `ets:new/2`
call crashed with `badarg` (named table already exists).

**3. Unprotected ETS access**

Seven functions accessed the ETS table with bare `ets:lookup`/`ets:insert`/`ets:delete`
calls — no `try/catch`. When the table was destroyed, these threw `badarg` inside
`decode_stream_message_for_selector/1`, which runs in the `receive` block of
`gleam_erlang_ffi:select/2`. The crash killed the stream process, but since it was
spawned unlinked (`process.spawn_unlinked`), no `on_stream_error` callback fired.
The stream silently died.

### Observed in production

- Three independent streaming requests hung for exactly 900,001ms (the monitor
  timeout), because the stream process crashed silently and no `on_stream_error`
  callback fired
- Zero crash reports appeared in CloudWatch logs

### The fix

**Persistent holder process for table ownership:**

`ensure_ref_mapping_table()` now spawns a dedicated `table_holder_loop/0` process
and transfers ETS table ownership to it via `ets:give_away/3`. This process runs
an infinite receive loop, so the table outlives any individual stream process.

```erlang
ensure_ref_mapping_table() ->
    case ets:info(?REF_MAPPING_TABLE) of
        undefined ->
            try
                ets:new(?REF_MAPPING_TABLE, [set, public, named_table]),
                Holder = spawn(fun table_holder_loop/0),
                ets:give_away(?REF_MAPPING_TABLE, Holder, undefined),
                ok
            catch
                error:badarg -> ok
            end;
        _ ->
            ok
    end.
```

**Race-safe creation:**

The `ets:new` call is wrapped in `try/catch error:badarg -> ok` so that if
another process creates the table between our `ets:info` check and our
`ets:new` call, the second attempt is a harmless no-op.

**Defensive try/catch on all ETS access:**

All seven bare ETS access functions now have `try/catch error:badarg` guards
with safe fallbacks (`none` for lookups, `ok` for writes/deletes, raw `Data`
for decompression). `get_or_create_string_id` additionally re-creates the
table on `badarg` for crash recovery.

### Regression tests (9 new tests, 194 total)

**Deterministic ETS-level tests:**

| Test | What it proves |
|---|---|
| `table_owner_is_dedicated_holder_not_caller` | Table owner is a separate holder process, not the calling process |
| `table_survives_creator_process_exit` | Table persists after the creating process exits |
| `stored_mappings_survive_creator_exit` | Data in the table is preserved after creator exits |
| `concurrent_table_creation_does_not_crash` | 20 concurrent calls to `ensure_ref_mapping_table()` all succeed |

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

- `modules/http_client/src/dream_http_client/dream_httpc_shim.erl` — Added
  `table_holder_loop/0`, rewrote `ensure_ref_mapping_table/0` with holder
  process and try/catch, wrapped all 7 bare ETS access functions in try/catch
- `modules/http_client/test/ets_table_ownership_test.gleam` — 9 new regression
  tests
- `modules/http_client/test/ets_table_ownership_ffi.erl` — Erlang FFI helper
  for ETS table introspection in tests
