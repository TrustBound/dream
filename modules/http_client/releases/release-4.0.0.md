# dream_http_client 4.0.0 Release Notes

**Release Date:** December 14, 2025

dream_http_client 4.0.0 redesigns recording/playback matching to support custom match keys and request transformers (for scrubbing/normalization) while preserving fast lookup and per-file storage.

## Key Highlights

- **Recorder builder API (BREAKING)**: configure record/playback via `recorder.new() |> ... |> recorder.start()`
- **Key-function matching (BREAKING)**: request identity is a user-provided function `RecordedRequest -> String`
- **Request transformer hook**: normalize/scrub requests before keying and before persistence
- **Response transformer hook**: scrub recorded responses before writing fixtures (Record mode only)
- **Ambiguous matches now error**: multiple recordings for the same key returns an explicit error
- **Safer filenames**: filenames now include both a key hash and content hash
- **More complete recorded responses**: recordings now persist response status + headers for blocking, and stream-start headers for streaming

## Breaking Changes

### 1) Recorder start is now builder-based

Before:

```gleam
let assert Ok(rec) = recorder.start(
  recorder.Playback(directory: "mocks/api"),
  matching.match_url_only(),
)
```

After:

```gleam
import dream_http_client/recorder.{directory, mode, start}

let assert Ok(rec) =
  recorder.new()
  |> directory("mocks/api")
  |> mode("playback")
  |> start()
```

Modes are now strict strings validated in `start()`:

- `"record"`
- `"playback"`
- `"passthrough"`

### 2) MatchingConfig removed in favor of match keys

`matching.MatchingConfig` and `matching.match_url_only()` are removed. Matching is now based on a key function:

```gleam
import dream_http_client/matching
import dream_http_client/recorder.{directory, key, mode, start}

let request_key_fn =
  matching.request_key(
    method: True,
    url: True,
    headers: False,
    body: False,
  )

let assert Ok(rec) =
  recorder.new()
  |> directory("mocks/api")
  |> mode("playback")
  |> key(request_key_fn)
  |> start()
```

### 3) Ambiguous playback now errors

If multiple recordings exist for the same computed key, playback returns an error like:

```
Ambiguous recording match for key: ...
```

This is intentional: it means your key/transformer is too coarse and should be refined.

`recorder.find_recording(...)` now returns `Result(Option(Recording), String)` so ambiguity can be surfaced.

### 4) `client.new` is now `client.new()`

For consistency with other builder entrypoints, `client.new` is now a zero-argument
function. Update call sites to add parentheses:

```gleam
// Before:
client.new |> client.host("example.com")

// After:
client.new() |> client.host("example.com")
```

## New: Request Transformer

You can normalize/scrub requests before matching and persistence:

```gleam
import dream_http_client/recording
import dream_http_client/recorder.{directory, mode, request_transformer, start}

fn scrub(req: recording.RecordedRequest) -> recording.RecordedRequest {
  // Example: strip auth header and drop body
  // (implementation omitted)
  req
}

let assert Ok(rec) =
  recorder.new()
  |> directory("mocks/api")
  |> mode("record")
  |> request_transformer(scrub)
  |> start()
```

Transformers run before:

- computing the key (record + playback)
- writing recordings to disk

## New: Response Transformer

If you need to scrub secrets from responses (cookies, tokens, PII) before fixtures
are written to disk, you can attach a response transformer:

```gleam
import dream_http_client/recording
import dream_http_client/recorder.{directory, mode, response_transformer, start}

fn scrub_response(
  request: recording.RecordedRequest,
  response: recording.RecordedResponse,
) -> recording.RecordedResponse {
  // scrub using request context if needed
  response
}

let assert Ok(rec) =
  recorder.new()
  |> directory("mocks/api")
  |> mode("record")
  |> response_transformer(scrub_response)
  |> start()
```

Note: response transformers run **only in Record mode** (before writing to disk).

## Recording Response Metadata

Recordings now persist more response metadata so fixtures can be safely shared and
so transformers have the information they need:

- **Blocking** recordings persist the response **status code** and **headers**
- **Streaming** recordings persist response **headers** captured from `stream_start`

## Storage Changes

### Filename format

Recording filenames now include both:

- a hash of the key (groups by matching identity)
- a hash of the file content (prevents overwriting when multiple recordings share a key)

Format:

```
{method}_{host}_{path}_{key_hash}_{content_hash}.json
```

## Upgrading

Update your dependency:

```toml
[dependencies]
dream_http_client = ">= 4.0.0 and < 5.0.0"
```
