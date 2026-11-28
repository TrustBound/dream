.PHONY: run test test-integration clean build

run:
	gleam run -m main

test:
	gleam test

test-integration:
	@echo "=== Running SSE integration tests ==="
	@if [ -z "$$CI" ]; then \
		echo "Killing any existing servers..."; \
		pkill -9 -f "gleam run.*main" 2>/dev/null || true; \
		pkill -9 -f "dream_example_sse" 2>/dev/null || true; \
		lsof -ti:8081 | xargs kill -9 2>/dev/null || true; \
		sleep 2; \
	fi
	@echo "Building Gleam application..."
	@rm -rf build/dev build/prod
	@output=$$(gleam build 2>&1) || { echo "$$output"; exit 1; }
	@echo "Starting server in background..."
	@../../integration/run-scenarios.sh sse 8081 main http1
	@../../integration/run-scenarios.sh sse 8081 tls_main http2

build:
	@gleam build

clean:
	gleam clean
