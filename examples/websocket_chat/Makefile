.PHONY: run test test-integration clean matcha build

run:
	gleam run -m main

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
	@../../integration/run-scenarios.sh websocket_chat 8080 main http1
	@../../integration/run-scenarios.sh websocket_chat 8080 tls_main http2

matcha:
	@matcha && gleam format src

build: matcha
	@gleam build

clean:
	gleam clean

