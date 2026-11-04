# Vendored mist

Dream ships a copy of the [mist](https://github.com/rawhat/mist) web server
inside its own source tree. This page says why, what it changes for you, and
how to remove the copy again.

## Why the copy exists

Dream needs HTTP/2 fixes that upstream mist 6.0.3 does not have yet. We made
them on a fork, `TrustBound/mist`, branch
`feature/svc-680-http2-fixes-on-v6.0.3`. Dream used that fork as a git
dependency. Hex does not accept packages with git dependencies, so Dream could
not be published.

The copy removes the git dependency. Dream now depends only on Hex packages,
and `gleam publish` works.

We do not plan to maintain a mist fork. The copy is temporary. It goes away
when upstream mist ships the fixes (tracked as U11 in the Dream Maintenance
project, Linear P-SVC-37).

## What is copied

| Item | Where |
|------|-------|
| mist source | `src/mist.gleam`, `src/mist/`, `src/mist_ffi.erl` |
| mist licence (Apache-2.0) | `src/mist/LICENSE` |
| mist tests | `test/vendored_mist/` (registered in `test/vendored_mist/suite.gleam`) |
| mist runtime dependencies | `[dependencies]` in `gleam.toml`, with mist's own version ranges |
| mist application start module | `[erlang] application_start_module = "mist@internal@clock"` in `gleam.toml` |
| attribution | "Third-party code" section in `README.md` |

- Upstream version: mist 6.0.3
- Fork commit the copy is based on: `dfba4fe` on
  `TrustBound/mist` branch `feature/svc-680-http2-fixes-on-v6.0.3`
  (upstream v6.0.3 plus our HTTP/2 fixes and small chores)

The module names are unchanged: `mist`, `mist/internal/...`. Dream's own
code (`src/dream/servers/mist/*.gleam`) imports them as before.

The test bodies under `test/vendored_mist/` are unchanged too. Only the
`scaffold` import moved to `vendored_mist/scaffold`, and
`test/vendored_mist/suite.gleam` wraps each `*_test` function as a dream_test
unit test. `test/dream_test.gleam` runs these suites one at a time, because
the HTTP/1 tests all listen on port 8888.

## Consequence: no second mist in the dependency tree

Gleam does not allow two packages to define the same module. Dream now
defines `mist`. If a project depends on Dream and, directly or through another
package, on the `mist` Hex package, `gleam build` fails with a duplicate
module error.

Rule for consumers: depend on Dream, not on `mist`. Dream re-exports what you
need through `dream/servers/mist/*`.

Rule for Dream contributors: do not add a dependency that pulls in `mist`.

## How to update the copy

If the fork gets a new fix before upstream ships it:

1. Clone the fork branch at the new commit.
2. Replace `src/mist.gleam`, `src/mist/` and `src/mist_ffi.erl` with the
   fork's `src/` tree. Keep `src/mist/LICENSE`.
3. Replace the test files under `test/vendored_mist/` with the fork's
   `test/` files. Keep `suite.gleam`. Re-apply the `vendored_mist/scaffold`
   import change. Add new `*_test` functions to `suite.gleam`.
4. Compare the fork's `gleam.toml` `[dependencies]` with Dream's and align
   the ranges.
5. Update the fork commit in this file and in `README.md`.
6. Run `gleam format`, `gleam build`, `gleam test`.

## How to remove the copy (U11)

Do this when an upstream mist release includes the HTTP/2 fixes. Call that
release `X.Y.Z`.

1. Delete `src/mist.gleam`, `src/mist/` (including `src/mist/LICENSE`) and
   `src/mist_ffi.erl`.
2. Delete `test/vendored_mist/`. Remove the `vendored_mist/suite` import and
   the vendored run block from `test/dream_test.gleam`.
3. In `gleam.toml`:
   - add `mist = ">= X.Y.Z and < (X+1).0.0"` to `[dependencies]`;
   - remove the mist runtime dependencies that Dream does not import itself
     (`glisten`, `gramps`, `hpack_erl`, `exception`, `logging`; check with
     `grep -r "^import" src/dream` first);
   - remove the `[erlang] application_start_module` line;
   - remove `gleam_hackney` from `[dev-dependencies]` if nothing else uses it.
4. Remove the "Third-party code" section from `README.md`.
5. Delete this file and its link in `docs/contributing/index.md`.
6. Regenerate the manifests: run `gleam deps download` in the repository
   root, in every `modules/*` directory and in every `examples/*` directory.
   Check that `manifest.toml` lists `mist` as a Hex package and has no
   `source = "git"` entry.
7. Run `gleam format --check`, `gleam build`, `gleam test`, and the module
   and example builds. Run `echo n | gleam publish` and check it reaches the
   confirmation prompt without an error.
