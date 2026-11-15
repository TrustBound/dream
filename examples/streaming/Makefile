.PHONY: run test test-integration clean

run:
	@gleam run -m main

test:
	@gleam test

test-integration:
	@echo "=== Running integration tests ==="
	@if [ -z "$$CI" ]; then \
		echo "Killing any existing servers..."; \
		pkill -9 -f "gleam run.*main" 2>/dev/null || true; \
		pkill -9 -f "dream_example_streaming" 2>/dev/null || true; \
		lsof -ti:3003 | xargs kill -9 2>/dev/null || true; \
		lsof -ti:9876 | xargs kill -9 2>/dev/null || true; \
		sleep 2; \
	fi
	@echo "Building Gleam application..."
	@rm -rf build/dev build/prod
	@gleam build > /dev/null 2>&1
	@echo "Starting server in background..."
	@../../integration/run-scenarios.sh streaming 3003 main http1
	@../../integration/run-scenarios.sh streaming 3003 tls_main http2

clean:
	@gleam clean

