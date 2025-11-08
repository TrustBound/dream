# Dream Library Development Makefile
# For example-specific commands, see individual example directories

.PHONY: test clean build format docs check

# Run the test suite
test:
	@gleam test

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

