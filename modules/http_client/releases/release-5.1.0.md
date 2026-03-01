# dream_http_client v5.1.0

**Release Date:** February 28, 2026

This release adds transparent gzip/deflate decompression across all three HTTP
client execution modes and fixes a high-severity bug where streaming requests
crash when the upstream server returns a non-streaming HTTP error response.

No API changes are required -- both the compression support and the bug fix are
fully transparent.

---

## Feature: Transparent gzip/deflate compression

The client now automatically handles compressed HTTP responses:

1. Injects `Accept-Encoding: gzip, deflate` on every outgoing request (unless
   you already set your own `Accept-Encoding` header)
2. Detects `Content-Encoding: gzip` or `Content-Encoding: deflate` in responses
3. Decompresses the body transparently before surfacing it to your code
4. Strips the `Content-Encoding` header after successful decompression

This applies to all three execution modes:
- `send()` (synchronous) -- body is decompressed before return
- `start_stream()` (callback-based) -- chunks are decompressed on-the-fly
- `stream_yielder()` (pull-based) -- chunks are decompressed on-the-fly

### Edge case handling

- **`Content-Encoding: identity`** -- treated as a no-op (body passed through unchanged)
- **Unrecognized encoding** (e.g. `br`, `zstd`) -- raw bytes passed through unchanged,
  a warning is logged via `io:format`
- **Corrupted compressed data** -- raw bytes passed through unchanged, a warning is logged
- **User-provided `Accept-Encoding`** -- if you explicitly set this header, the client
  will NOT inject its own. Your header takes precedence.

### Implementation details

All decompression is handled in the Erlang FFI shim (`dream_httpc_shim.erl`). The
Gleam client code has zero changes -- this is entirely transparent.

For streaming modes, zlib inflate contexts are initialized when `stream_start`
arrives with a `Content-Encoding` header, used to decompress each chunk, and cleaned
up when the stream ends or errors. The pull-based path (`stream_owner_wait`) threads
the zlib context through process state; the message-based path
(`decode_stream_message_for_selector`) stores it in the existing ETS ref mapping table.

Window bits:
- gzip: 31 (zlib + gzip header detection)
- deflate: 15 (raw zlib wrapper)

### Disabling compression

If you need to disable automatic compression for a specific request, set your
own `Accept-Encoding` header:

```gleam
client.new()
|> client.headers([client.Header("Accept-Encoding", "identity")])
|> client.send()
```

---

## Bug Fix: Streaming crashes on non-streaming upstream responses

When using `start_stream()` or `stream_yielder()` to make a streaming HTTP
request, and the upstream responds with an HTTP error instead of starting an
SSE stream, Erlang's `httpc` sends a complete response message rather than
the expected `stream_start`/`stream`/`stream_end` sequence. This complete
response tuple was unhandled in four locations in the Erlang FFI shim,
causing crashes, hangs, or silent data loss depending on which code path
was hit.

In practice, this meant that every streaming request where the upstream
returned an HTTP error (invalid API key, rate limit, server error) would
either crash the stream process or hang indefinitely. The `on_stream_error`
callback was never invoked, the caller timed out after 30 seconds with a
504, and the actual upstream error details were lost entirely.

### Bug details

`httpc:request/4` with `{stream, self}` and `{sync, false}` can emit two
classes of messages:

**Streaming messages (handled in 5.0.0):**

```erlang
{http, {RequestId, stream_start, Headers}}
{http, {RequestId, stream, BinBodyPart}}
{http, {RequestId, stream_end, Headers}}
{http, {RequestId, {error, Reason}}}
```

**Complete response message (NOT handled in 5.0.0):**

```erlang
{http, {RequestId, {{HttpVersion, StatusCode, ReasonPhrase}, Headers, Body}}}
```

### Affected code paths

| Function | Behavior in 5.0.0 | Fixed in 5.1.0 |
|:---------|:-------------------|:---------------|
| `decode_stream_message_for_selector/1` | Crashed with `error(badarg)` | Routes to `stream_error` |
| `receive_stream_message/1` | Timed out silently | Returns `stream_error` with status and body |
| `stream_owner_wait/5` | Silently discarded message, process hung | Buffers error for delivery |
| `stream_owner_next_message/2` | Recursed forever (infinite loop) | Returns error immediately |

The complete response is now converted to a `stream_error` event with a formatted
error message containing the HTTP status code and response body:

```
HTTP 401 Unauthorized: {"error":{"message":"Incorrect API key provided"}}
```

### Reproduction scenario

Any streaming request where the upstream returns an HTTP error instead of
starting a stream. Common examples:

- Invalid API key to OpenAI (HTTP 401)
- Rate limited by any API (HTTP 429)
- Server error from upstream (HTTP 500)
- Forbidden access (HTTP 403)

```gleam
let req = client.new()
  |> client.method(http.Post)
  |> client.scheme(http.Https)
  |> client.host("api.openai.com")
  |> client.path("/v1/chat/completions")
  |> client.add_header("Authorization", "Bearer INVALID_KEY")
  |> client.body("{\"model\":\"gpt-4o\",\"stream\":true,\"messages\":[{\"role\":\"user\",\"content\":\"hello\"}]}")
  |> client.on_stream_error(fn(reason) { io.println("error: " <> reason) })

// 5.0.0: crashes the stream process, caller times out
// 5.1.0: on_stream_error fires with "HTTP 401 Unauthorized: {...}"
let assert Ok(_handle) = client.start_stream(req)
```

---

## Test coverage

34 new tests total (168 tests pass across the entire suite):

| Category | Count | Coverage |
|----------|-------|----------|
| Sync decompression (send) | 7 | gzip, deflate, identity, unknown, none, user header, corrupted |
| Callback streaming (start_stream) | 4 | gzip, deflate, unknown, uncompressed |
| Pull streaming (stream_yielder) | 4 | gzip, deflate, unknown, uncompressed |
| Header injection | 6 | auto-inject x3 modes, preserve-custom x3 modes |
| Zlib lifecycle cleanup | 3 | normal end x2, error cleanup |
| Non-streaming response (start_stream) | 5 | 401, 500, status code check, body check, clean exit |
| Non-streaming response (stream_yielder) | 3 | 401, 500, body check |
| Regression guards | 2 | normal streaming still works |

## Mock server additions

New endpoints added to `dream_mock_server`:

Non-streaming:
- `GET /gzip` -- gzip-compressed response
- `GET /deflate` -- deflate-compressed response
- `GET /identity` -- `Content-Encoding: identity` response
- `GET /unknown-encoding` -- `Content-Encoding: br` (simulates unsupported)
- `GET /corrupted-gzip` -- garbage bytes with `Content-Encoding: gzip`
- `GET /echo-accept-encoding` -- echoes the received `Accept-Encoding` header

Streaming:
- `GET /stream/gzip` -- gzip-compressed stream (5 chunks)
- `GET /stream/deflate` -- deflate-compressed stream (5 chunks)
- `GET /stream/unknown-encoding` -- raw stream with `Content-Encoding: br`

## Upgrading

Update your dependency:

```toml
[dependencies]
dream_http_client = ">= 5.1.0 and < 6.0.0"
```

Then run:

```bash
gleam deps download
```

No breaking changes. All existing code works without modification. After
upgrading, your HTTP client will automatically request and decompress
gzip/deflate responses, and streaming requests to error-returning upstreams
will fire `on_stream_error` instead of crashing.

## Documentation

- [dream_http_client hexdocs](https://hexdocs.pm/dream_http_client) -- v5.1.0
- [README](https://github.com/TrustBound/dream/tree/main/modules/http_client)
- [CHANGELOG](https://github.com/TrustBound/dream/blob/main/modules/http_client/CHANGELOG.md)

## Community

- [Full Documentation](https://github.com/TrustBound/dream/tree/main/modules/http_client)
- [Discussions](https://github.com/TrustBound/dream/discussions)
- [Report Issues](https://github.com/TrustBound/dream/issues)
- [Contributing Guide](https://github.com/TrustBound/dream/blob/main/CONTRIBUTING.md)

---

**Full Changelog:** [CHANGELOG.md](https://github.com/TrustBound/dream/blob/main/modules/http_client/CHANGELOG.md)
