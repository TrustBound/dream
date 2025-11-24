# Dream Library Development Makefile
# For example-specific commands, see individual example directories

.PHONY: test test-dream test-unit test-integration clean build format docs check

# Run all tests (unit + integration)
test:
	@make test-unit
	@echo ""
	@make test-integration

# Run Dream core tests only
test-dream:
	@gleam test

# Run all unit tests (core + modules)
test-unit:
	@echo "=== Testing Dream Core ==="
	@gleam test
	@echo ""
	@echo "=== Testing dream_http_client ==="
	@cd modules/http_client && make test
	@echo ""
	@echo "=== Testing dream_mock_server ==="
	@cd modules/mock_server && make test
	@echo ""
	@echo "✅ All unit tests passed!"

# Clean build artifacts
clean:
	@gleam clean
	@rm -rf coverage
	@rm -f erl_crash.dump
	@find build -name "*.beam" -type f -delete 2>/dev/null || true

# Build the library
build:
	@gleam build

# Format code
format:
	@gleam format

# Generate documentation
docs:
	@gleam docs build

# Run format check and build (useful for CI)
check:
	@gleam format --check
	@gleam build
	@gleam test

# Run all integration tests (modules + examples, requires PostgreSQL on port 5435)
test-integration:
	@echo "=== Running Module Integration Tests ==="
	@echo ""
	@echo "=== Testing dream_mock_server ==="
	@cd modules/mock_server && make test-integration || exit 1
	@echo ""
	@echo "=== Running Example Integration Tests ==="
	@for example in simple custom_context static streaming rate_limiter database multi_format streaming_capabilities; do \
		echo ""; \
		echo "=== Testing $$example ==="; \
		cd examples/$$example && make test-integration || exit 1; \
		cd ../..; \
	done
	@echo ""
	@echo "✅ All integration tests passed!"

