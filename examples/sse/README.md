# Dream SSE Example

Demonstrates Server-Sent Events using Dream's `upgrade_to_sse` function,
which uses mist's native OTP actor-based SSE implementation.

## Endpoints

- `GET /events` — streams numbered events every 100ms
- `GET /events/named` — streams named events with IDs every 100ms

## Running

```bash
make run
```

Then open `http://localhost:8081/events` in a browser or:

```bash
curl -N http://localhost:8081/events
```

## Integration Tests

```bash
make test-integration
```

Requires Elixir and Mix for Cucumber test runner.
