# Dream SSE Example

Demonstrates Server-Sent Events using Dream's `upgrade_to_sse` function,
which uses mist's native OTP actor-based SSE implementation.

## Endpoints

- `GET /events` — streams numbered events every 100ms
- `GET /events/named` — streams named events with IDs every 100ms

## Running

### Start the server <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/sse/test/integration/start.sh#L3-L4"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
cd examples/sse
make run
```

Then open `http://localhost:8081/events` in a browser or use curl. `head` stops it after the first three events:

### Read the events <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/sse/test/integration/readme.sh#L3"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
curl -N http://localhost:8081/events | head -n 6
```

### The first three events <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/sse/test/integration/readme_output.txt#L1-L5"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
data: {"count": 0}

data: {"count": 1}

data: {"count": 2}
```

## Integration Tests

From the repository root:

### Run the integration tests <a href="https://github.com/TrustBound/dream/blob/3.0.0/scripts/test-integration.sh#L17"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
(cd examples/sse && make test-integration)
```

Requires Elixir and Mix for Cucumber test runner.
