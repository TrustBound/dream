# Dream's HTTP server packages

Dream's router, controllers and HTTP types do not depend on any web server.
The server is an adapter, under `src/dream/servers/`. The one adapter Dream
ships today is built on [mist](https://github.com/rawhat/mist), the HTTP
server, and mist is built on [glisten](https://github.com/rawhat/glisten),
the socket server. Both are by Alex Manning (rawhat) and their contributors, and both
are licensed under Apache-2.0.

The Mist adapter does not use the `mist` and `glisten` Hex packages
directly. It uses two forks that we publish:

| Package | What it is | Fork and branch |
|---------|------------|-----------------|
| `dream_http_server` | mist 6.0.3 plus 47 fixes, most of them for HTTP/2 | [TrustBound/mist](https://github.com/TrustBound/mist), `dream-http-server` |
| `dream_socket_server` | glisten 9.0.1 plus a socket buffer fix | [TrustBound/glisten](https://github.com/TrustBound/glisten), `dream-socket-server` |

The `dream` package depends on `dream_http_server`, because the adapter is
part of the package, and `dream_http_server` depends on
`dream_socket_server`.

## Why forks

1. **The adapter needed many fixes, not one.** HTTP/2 in mist 6.0.3 was not
   finished. Requests with a body got no response, every request left a
   process behind, large responses stalled, and several kinds of client input
   closed or crashed the whole connection. The fixes are listed in the
   changelog of the fork.
2. **Giving that many changes back takes a long time.** Each change goes
   upstream as its own small pull request, in the maintainer's style, and is
   reviewed and released on the maintainer's schedule. That is the right way
   to do it, and it cannot be hurried. We intend to send every one of them.
3. **This version of Dream had already been delayed too long.**
4. **Hex and Gleam leave no other way to ship a fixed dependency.** A Hex
   package may depend only on other Hex packages, so Dream cannot depend on a
   git fork or a local path. A Gleam package is built only from the real
   files in its own `src/` folder, so a git submodule cannot be Dream's
   source either: we tested links from `src/` into a submodule, and the
   published package came out with the files in the wrong place. The choices
   left were to copy the source into Dream or to publish the forks. Publishing
   keeps each library's code, history and licence in one place.

The forks are named for what they do, so they do not appear when people
search Hex for mist or glisten. They are temporary: when upstream releases
contain the fixes, the adapter goes back to `mist` and `glisten`.

## What this means for you

- **The module names are unchanged.** The forks define `mist`, `mist/...`,
  `glisten` and `glisten/...`, and Dream's code under
  `src/dream/servers/mist/` imports them as before.
- **Do not add `mist` or `glisten` to a project that uses Dream.** Two
  packages cannot define the same module, and Gleam stops the build with a
  duplicate module error. Dream re-exports what you need through
  `dream/servers/mist/*`.
- **Report server problems to our forks**, not to the mist or glisten
  maintainers. They did not publish these packages and do not support them.

## How to update a fork

1. Commit the fix on the fork's fix branch (`http2-review-fixes` for mist,
   `socket-buffer-9.0.1` for glisten), in the upstream style, with a test.
   Never rename, reformat or restyle the upstream source: what we publish is
   what we send upstream.
2. Bring the fix into the release branch (`dream-http-server` or
   `dream-socket-server`), raise the version in its `gleam.toml`, and add a
   changelog entry.
3. Publish the fork. `dream_socket_server` goes first when both change.
4. In Dream, raise the range in `gleam.toml` if needed and regenerate the
   lock files. Resolve one project at a time with a pause between projects,
   because every resolution asks the Hex API about every package and Hex
   limits those calls. `scripts/after-fork-publish.sh` does this.
5. Run `make test-unit`. Then run the tests of
   [dream_http_client](https://github.com/TrustBound/dream_http_client)
   against this Dream. They drive a real HTTP/2 client against the mock
   server, which serves its requests through the HTTP server package.

## How to go back to mist and glisten

Do this when mist and glisten releases contain the fixes.

1. In `gleam.toml`, replace `dream_http_server` with the `mist` range.
2. Regenerate the lock files as in step 4 above.
3. Run `make test-unit` and `make test-integration`.
4. Remove this page, its link in `docs/contributing/index.md` and the
   "Third-party code" section in `README.md`, and publish final releases of
   the two forks that say they are retired.
