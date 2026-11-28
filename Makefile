# Dream Library Development Makefile
# For example-specific commands, see individual example directories

.PHONY: test test-dream test-unit test-integration setup-integration-dbs clean build format docs check check-snippets check-templates test-docker test-tasks install-hooks

# Run all tests (unit + integration)
test:
	@make test-unit
	@echo ""
	@make test-integration

# Run Dream core tests only
test-dream:
	@gleam test

# Run all unit tests. The run measures line coverage of src/ and fails when
# it is below 100% (see test/dream_test.gleam).
test-unit:
	@echo "=== Testing Dream Core ==="
	@gleam test
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
	@gleam run -m docs_snippet_pages

# Format check, build, unit tests and snippet check (what the unit job of CI runs)
check:
	@sh scripts/check.sh

# Check that every code block in the docs is proven: Gleam blocks match the
# tested snippet that their badge links to, and file, command and output
# blocks match a file that the tests or CI use (see
# docs/contributing/contributing.md)
check-snippets:
	@gleam run -m dream_snippets

# Check that the generated Matcha template modules of the docs and the
# examples are up to date (needs the matcha binary)
check-templates:
	@sh scripts/check-templates.sh

# Build the Docker image of examples/deployment and start it with Docker
# Compose (needs Docker and the port 3000 free)
test-docker:
	@sh scripts/test-docker.sh

# Run the integration and Cypress E2E tests of examples/tasks (needs Docker,
# the matcha binary and Node.js)
test-tasks:
	@sh scripts/test-tasks.sh

# Install repo-managed git hooks into .git/hooks/
# (Git does not version-control .git/hooks, so this must be run per-clone.)
install-hooks:
	@mkdir -p .git/hooks
	@chmod +x .githooks/* 2>/dev/null || true
	@cp -f .githooks/* .git/hooks/
	@echo "✅ Installed git hooks into .git/hooks/"

# Run all example integration tests (requires PostgreSQL on port 5435)
test-integration:
	@echo "=== Running Example Integration Tests ==="
	@sh scripts/test-integration.sh

# Set up local PostgreSQL and migrations for examples that require it
setup-integration-dbs:
	@echo "=== Setting up PostgreSQL for integration tests ==="
	@cd examples/database && make db-up
	@cd examples/database && docker-compose exec -T postgres psql -U postgres -c "DROP DATABASE IF EXISTS dream_example_database_db;" > /dev/null 2>&1
	@cd examples/database && docker-compose exec -T postgres psql -U postgres -c "CREATE DATABASE dream_example_database_db;" > /dev/null 2>&1
	@cd examples/database && docker-compose exec -T postgres psql -U postgres -c "DROP DATABASE IF EXISTS dream_example_multi_format_db;" > /dev/null 2>&1
	@cd examples/database && docker-compose exec -T postgres psql -U postgres -c "CREATE DATABASE dream_example_multi_format_db;" > /dev/null 2>&1
	@cd examples/database && export DATABASE_URL=postgres://postgres:postgres@localhost:5435/dream_example_database_db && gleam run -m cigogne all
	@cd examples/multi_format && export DATABASE_URL=postgres://postgres:postgres@localhost:5435/dream_example_multi_format_db && gleam run -m cigogne all
