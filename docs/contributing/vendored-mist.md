# Vendored mist and glisten

Dream ships copies of two libraries inside its own source tree:

- [mist](https://github.com/rawhat/mist), the web server
- [glisten](https://github.com/rawhat/glisten), the socket library that mist
  runs on

Both are written by Alex Manning (rawhat) and their contributors, under the
Apache-2.0 licence. This page says why the copies exist, what is in them, what
they change for you, and how to remove them again.

## Why we vendored

Mist and glisten have given a great deal to us and to the rest of the Gleam
community. We want to give back to both projects, and that is still the plan.
The copies are here for four reasons.

1. **Dream needed many fixes, not one.** HTTP/2 in upstream mist 6.0.3 was not
   finished. Requests with a body did not get a response, every request left a
   process behind, large responses stalled, and several kinds of client input
   closed or crashed the whole connection. Making HTTP/2 correct for Dream took
   more than forty separate changes to mist and two to glisten. They are
   listed below.
2. **Contributing that many changes takes a long time.** Each change has to go
   upstream as its own small pull request, in the maintainer's style, and be
   reviewed and released on the maintainer's schedule. That is the right way
   to do it, and it cannot be hurried.
3. **This version of Dream has already been delayed too long.** Dream could
   not be published while it depended on a fork: Hex does not accept packages
   with git dependencies. Waiting for every pull request to be merged and
   released would have delayed Dream by months more.
4. **The fixes have to reach Dream's users now.** Shipping the corrected
   source inside Dream lets us release, while the same changes go upstream at
   the pace the upstream projects can take them.

The copies are temporary. When upstream releases contain the fixes, Dream goes
back to the Hex packages (see "How to remove the copies").

We have not opened the upstream pull requests yet. They follow once this
version of Dream is released and proven.

## How the copies are kept

The two libraries live in this repository twice, on purpose.

- **The source of truth is two git submodules.** `vendor/mist` points at our
  fork [TrustBound/mist](https://github.com/TrustBound/mist) and
  `vendor/glisten` at our fork
  [TrustBound/glisten](https://github.com/TrustBound/glisten). Each is pinned
  to one exact commit, so git records which fix-branch commit Dream uses, and
  the full history of every fix is one `git log` away in the submodule.
- **The files under `src/` and `test/` are generated from the submodules.**
  The Gleam compiler and the Hex package only take real files under `src/`.
  We tested links from `src/` into the submodule: the build works, but the
  Hex package then carries the files at `vendor/mist/src/`, where a project
  that installs Dream cannot find them. So `make vendor-sync` copies the
  files, and `make vendor-check` fails when a copy differs from its
  submodule. CI and the pre-commit hook run the check.

After you clone Dream, fetch the submodules once:

```sh
git submodule update --init
```

Never edit a generated file. Change the fork, move the submodule to the new
commit, and run `make vendor-sync`.

## What is copied

| Item | Where |
|------|-------|
| mist submodule (source of truth) | `vendor/mist` |
| glisten submodule (source of truth) | `vendor/glisten` |
| mist source | `src/mist.gleam`, `src/mist/`, `src/mist_ffi.erl` |
| mist licence (Apache-2.0) | `src/mist/LICENSE` |
| mist tests | `test/vendored_mist/` |
| glisten source | `src/glisten.gleam`, `src/glisten/`, `src/glisten_ffi.erl`, `src/glisten_ssl_ffi.erl`, `src/glisten_tcp_ffi.erl` |
| glisten licence (Apache-2.0) | `src/glisten/LICENSE` |
| glisten tests | `test/vendored_glisten/` |
| test registration | `test/vendored_mist/suite.gleam` |
| runtime dependencies of both | `[dependencies]` in `gleam.toml`, with their own version ranges |
| mist application start module | `[erlang] application_start_module = "mist@internal@clock"` in `gleam.toml` |
| `ssl` application for glisten | `[erlang] extra_applications = ["ssl"]` in `gleam.toml` |
| attribution | "Third-party code" section in `README.md` |

The module names are unchanged: `mist`, `mist/internal/...`, `glisten`,
`glisten/...`. Dream's own code (`src/dream/servers/mist/*.gleam`) imports
them as before.

### mist

- Upstream base: mist 6.0.3 (upstream commit `6be7897`)
- Copied from: the `vendor/mist` submodule, branch `http2-review-fixes` of our
  fork, commit `4aebd5f`, which is that release plus the changes below, one
  commit each

What the changes do:

- HTTP/1: a response sent just before the connection closes is no longer lost
  to a connection reset.
- HTTP/2 requests: the request path, method, scheme and host are applied;
  request bodies are delivered, with or without a `content-length`, and
  checked against it when it is given; headers split across frames and
  request trailers are handled; the body size limit is enforced while reading.
- HTTP/2 responses: large bodies and large headers are split into frames; flow
  control is respected; server-sent events, chunked responses and file
  responses work; headers and body go out in one write.
- HTTP/2 connection handling: settings from the client are applied; `PING` is
  answered; a stream that the client resets stops its handler; stream
  processes are cleaned up; stream numbers cannot be reused; frames sent with
  the client preface are processed.
- Errors: bad input gets the error the HTTP/2 specification asks for (a stream
  reset or a `GOAWAY`) and no longer crashes or silently stalls the
  connection; a handler that fails answers 500 on its own stream only;
  oversized frames and oversized header blocks are refused.
- Limits and flow control: at most 100 streams run at once on a connection,
  and more are refused; the window for a request body is granted as the
  handler reads it, so an upload cannot pile up in memory; frame padding is
  counted.
- Settings: `mist.with_read_timeout` sets how long to wait for request data
  (15 seconds by default, for HTTP/1 and HTTP/2), and
  `mist.with_send_timeout` sets how long an HTTP/2 chunked or
  server-sent-events send waits for the client (30 seconds by default).
- Uploads: the HTTP/2 receive window for a request body is 1 MiB, where the
  protocol default is 65,535 bytes, so a large upload needs far fewer round
  trips. `mist.with_initial_window_size` changes it. The server may hold up
  to this many unread bytes for each stream.
- Slow clients: a chunked or server-sent-events response waits for the client
  and no longer piles up in server memory; a send that times out is cancelled.
- Tests: the test server no longer races the tests for its port.

The commit list is the authority. Read it with
`git -C vendor/mist log --oneline 6be7897..4aebd5f`.

### glisten

- Upstream base: glisten 9.0.1
- Copied from: the `vendor/glisten` submodule, branch `socket-buffer-9.0.1`
  of our fork, commit `5340a31`, which is that release plus two changes

What the changes do:

- Glisten no longer sets every socket's read buffer to the size of the
  kernel's receive buffer. Under load that step held a large buffer for every
  read (about 3,000 MB against 155 MB in the same test on macOS, and 139 MB
  against about 70 MB on Linux) and gave no measurable speed.
- `glisten.with_buffer_size` sets the buffer for anyone who wants a different
  size.

### What is not changed

The copied source is never reformatted or tidied. It must stay byte for byte
the same as the fix branches, so that what Dream ships is exactly what goes
upstream. For that reason the format check in the pre-commit hook, the
`Makefile` and CI skips the copied source, and compiler warnings from it do
not fail the hook.

`scripts/vendor.sh` is the one definition of how the copies are made.
`make vendor-sync` and `make vendor-check` call it. It does not copy three
upstream test files: mist's `mist_test.gleam` (it only starts gleeunit) and
`websocket_test.gleam` (it needs a package Dream does not depend on), and
glisten's `test_utils.gleam` (nothing imports it).

The test bodies under `test/vendored_mist/` and `test/vendored_glisten/` are
unchanged too, with three mechanical exceptions: the `scaffold` and
`tcp_client` imports point at their new module paths, glisten's `main`
function (which starts gleeunit) is removed, and
`test/vendored_mist/suite.gleam` wraps each `*_test` function as a dream_test
unit test. `test/dream_test.gleam` runs these suites one at a time, because
they share ports.

## Consequence: no second mist or glisten in the dependency tree

Gleam does not allow two packages to define the same module. Dream now
defines `mist` and `glisten`. If a project depends on Dream and, directly or
through another package, on the `mist` or `glisten` Hex package, `gleam build`
fails with a duplicate module error.

Rule for consumers: depend on Dream, not on `mist` or `glisten`. Dream
re-exports what you need through `dream/servers/mist/*`.

Rule for Dream contributors: do not add a dependency that pulls in `mist` or
`glisten`.

If a project already has a `manifest.toml` from before this change, it still
lists the Hex packages and the build fails with the duplicate module error.
Run `gleam deps update dream` in that project once. It removes them from the
lock file.

## How to update the copies

If a fix branch gets a new commit before upstream ships it:

1. Push the new commit to the fork. A submodule can only point at a commit
   that exists on GitHub.
2. Move the submodule to it: `git -C vendor/mist fetch` and
   `git -C vendor/mist checkout <commit>` (or the same in `vendor/glisten`).
3. Run `make vendor-sync`. It regenerates the copied source, licences and
   tests. Do not run `gleam format` on the copied source.
4. Add any new `*_test` function to `test/vendored_mist/suite.gleam`. That
   file is written by hand; `make vendor-check` tells you which tests are
   missing.
5. Compare the fork's `gleam.toml` `[dependencies]` with Dream's and align
   the ranges.
6. Update the commit ids on this page and in `README.md`.
7. Run `make vendor-check`, then `make test-unit`. The module tests matter:
   `modules/http_client` drives a real HTTP/2 client against the mock
   server, which runs on the vendored mist.

## How to remove the copies

Do this when upstream releases include the fixes. Call the releases mist
`X.Y.Z` and glisten `A.B.C`. The two can be removed separately; mist needs a
glisten release that it is compatible with.

1. Remove the submodule (`git submodule deinit vendor/mist` and
   `git rm vendor/mist`, or the same for `vendor/glisten`) and delete the
   source files listed in "What is copied", including the `LICENSE` file.
2. Delete `test/vendored_mist/` and `test/vendored_glisten/`. Remove the
   `vendored_mist/suite` import and the vendored run block from
   `test/dream_test.gleam`.
3. In `gleam.toml`:
   - add `mist = ">= X.Y.Z and < (X+1).0.0"` to `[dependencies]`;
   - remove the runtime dependencies that Dream does not import itself
     (`gramps`, `hpack_erl`, `exception`, `logging`; check with
     `grep -r "^import" src/dream` first);
   - remove the `[erlang] application_start_module` and
     `extra_applications` lines;
   - remove `gleam_hackney` and `hackney` from `[dev-dependencies]` if
     nothing else uses them.
4. Remove the vendored-path exclusions from the format check in
   `.githooks/pre-commit`, the `Makefile` and the CI workflow, and remove
   the `vendor-sync` and `vendor-check` steps once both copies are gone.
5. Remove the "Third-party code" section from `README.md`.
6. Delete this file and its link in `docs/contributing/index.md`.
7. Regenerate the lock files: run `gleam deps download` in the repository
   root, in every `modules/*` directory and in every `examples/*` directory.
   Check that `manifest.toml` lists `mist` and `glisten` as Hex packages and
   has no `source = "git"` entry.
8. Run `gleam format --check`, `gleam build`, `gleam test`, and the module
   and example builds. Run `echo n | gleam publish` and check it reaches the
   confirmation prompt without an error.
