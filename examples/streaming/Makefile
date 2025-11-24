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
	@make clean > /dev/null 2>&1 || true
	@gleam build > /dev/null 2>&1
	@echo "Starting server in background..."
	@gleam run -m main > /tmp/streaming_test.log 2>&1 & \
	SERVER_PID=$$!; \
	echo "Server PID: $$SERVER_PID"; \
	echo "Waiting for server to be ready..."; \
	for i in $$(seq 1 30); do \
		if curl -s http://localhost:3003/ > /dev/null 2>&1; then \
			echo "Server is ready!"; \
			break; \
		fi; \
		if [ $$i -eq 30 ]; then \
			echo "Server failed to start"; \
			tail -20 /tmp/streaming_test.log; \
			kill $$SERVER_PID 2>/dev/null || true; \
			exit 1; \
		fi; \
		sleep 1; \
	done; \
	echo "Running Cucumber tests..."; \
	mix deps.get > /dev/null 2>&1 && MIX_ENV=test mix test; \
	TEST_EXIT=$$?; \
	echo "Stopping server..."; \
	kill $$SERVER_PID 2>/dev/null || true; \
	sleep 2; \
	kill -9 $$SERVER_PID 2>/dev/null || true; \
	lsof -ti:3003 2>/dev/null | xargs -r kill -9 2>/dev/null || true; \
	lsof -ti:9876 2>/dev/null | xargs -r kill -9 2>/dev/null || true; \
	if [ -z "$$CI" ]; then \
		pkill -9 -f "dream_example_streaming" 2>/dev/null || true; \
		sleep 1; \
	fi; \
	exit $$TEST_EXIT

clean:
	@gleam clean

