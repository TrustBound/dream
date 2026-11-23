.PHONY: run build test test-integration clean format check

run:
	@gleam run -m main

build:
	@gleam build

test:
	@gleam test

# Starts the server with test/integration/start.sh and runs the request of
# the README (test/integration/readme.sh) against it.
test-integration:
	@echo "=== Running integration tests ==="
	@if [ -z "$$CI" ]; then \
		lsof -ti:3000 | xargs kill -9 2>/dev/null || true; \
	fi
	@echo "Building Gleam application..."
	@output=$$(gleam build 2>&1) || { echo "$$output"; exit 1; }
	@../../integration/run-scenarios.sh simplest 3000 main http1

clean:
	@gleam clean

format:
	@gleam format

check:
	@gleam check
