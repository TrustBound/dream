.PHONY: run test test-integration clean

run:
	@gleam run -m main

test:
	@make test-integration

test-integration:
	@echo "=== Running integration tests ==="
	@if [ -z "$$CI" ]; then \
		echo "Stopping the server of an earlier run..."; \
		../../integration/example-server.sh stop build/server.pid; \
	fi
	@echo "Building Gleam application..."
	@rm -rf build/dev build/prod
	@output=$$(gleam build 2>&1) || { echo "$$output"; exit 1; }
	@echo "Starting server in background..."
	@../../integration/run-scenarios.sh static 3000 main http1
	@../../integration/run-scenarios.sh static 3000 tls_main http2

clean:
	@gleam clean

