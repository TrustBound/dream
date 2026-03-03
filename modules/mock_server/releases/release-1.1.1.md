# Dream Mock Server Release 1.1.1: GET /get now echoes query parameters

**Release Date:** March 3, 2026

This patch release fixes the `GET /get` endpoint to actually echo query
parameters as documented since 1.0.0.

## What was fixed

The `GET /get` endpoint was listed as "Echo query parameters" in the CHANGELOG
and endpoint documentation, but the implementation only passed `request.path` to
the view layer. The query string was silently ignored.

Now the controller passes `request.query` to the view, and the JSON response
includes a `"query"` field:

```json
{"method":"GET","url":"/get","query":"page=1&limit=10","headers":[]}
```

When no query string is present, the field contains an empty string:

```json
{"method":"GET","url":"/get","query":"","headers":[]}
```

## Files changed

- `src/dream_mock_server/controllers/api_controller.gleam` — `get()` now passes
  `request.query` to `api_view.get_to_json`
- `src/dream_mock_server/views/api_view.gleam` — `get_to_json` and
  `get_to_json_object` now accept a `query` parameter and include it in the
  JSON output

## Backward compatibility

The JSON response for `GET /get` now has an additional `"query"` field. Callers
that parse only `"method"` and `"url"` are unaffected. Callers that do strict
schema validation may need to accept the new field.
