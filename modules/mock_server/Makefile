.PHONY: run test test-integration clean

run:
	@gleam run -m standalone

test:
	@if [ -z "$$CI" ]; then \
		pkill -9 -f "dream_mock_server" 2>/dev/null || true; \
		lsof -ti:19876 | xargs kill -9 2>/dev/null || true; \
		lsof -ti:19877 | xargs kill -9 2>/dev/null || true; \
		lsof -ti:19878 | xargs kill -9 2>/dev/null || true; \
		lsof -ti:19880 | xargs kill -9 2>/dev/null || true; \
		lsof -ti:19881 | xargs kill -9 2>/dev/null || true; \
		lsof -ti:19882 | xargs kill -9 2>/dev/null || true; \
		lsof -ti:19883 | xargs kill -9 2>/dev/null || true; \
		sleep 2; \
	fi
	@gleam test
	@if [ -z "$$CI" ]; then \
		pkill -9 -f "dream_mock_server" 2>/dev/null || true; \
		sleep 1; \
	fi

test-integration:
	@echo "=== Running integration tests ==="
	@if [ -z "$$CI" ]; then \
		echo "Killing any existing servers..."; \
		pkill -9 -f "gleam run.*main" 2>/dev/null || true; \
		pkill -9 -f "dream_mock_server" 2>/dev/null || true; \
		lsof -ti:3004 | xargs kill -9 2>/dev/null || true; \
		sleep 2; \
	fi
	@echo "Building Gleam application..."
	@rm -rf build/dev build/prod
	@gleam build > /dev/null 2>&1
	@echo "Starting server in background..."
	@../../integration/run-scenarios.sh mock_server 3004 standalone http1
	@../../integration/run-scenarios.sh mock_server 3004 tls_standalone http2

clean:
	@gleam clean


