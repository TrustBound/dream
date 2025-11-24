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
	@make clean > /dev/null 2>&1 || true
	@gleam build > /dev/null 2>&1
	@echo "Starting server in background..."
	@gleam run -m standalone > /tmp/mock_server_test.log 2>&1 & \
	SERVER_PID=$$!; \
	echo "Server PID: $$SERVER_PID"; \
	echo "Waiting for server to be ready..."; \
	for i in $$(seq 1 30); do \
		if curl -s http://localhost:3004/ > /dev/null 2>&1; then \
			echo "Server is ready!"; \
			break; \
		fi; \
		if [ $$i -eq 30 ]; then \
			echo "Server failed to start"; \
			tail -20 /tmp/mock_server_test.log; \
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
	lsof -ti:3004 2>/dev/null | xargs -r kill -9 2>/dev/null || true; \
	if [ -z "$$CI" ]; then \
		pkill -9 -f "dream_mock_server" 2>/dev/null || true; \
		sleep 1; \
	fi; \
	exit $$TEST_EXIT

clean:
	@gleam clean


