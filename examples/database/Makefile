# Docker Compose database connection URL
DATABASE_URL = postgres://postgres:postgres@localhost:5435/dream_example_database_db

.PHONY: run test test-integration clean db-up db-down db-logs db-shell db-reset migrate migrate-up migrate-down migrate-new squirrel

run:
	@gleam run -m main

test:
	@make test-integration

test-integration:
	@echo "=== Running integration tests ==="
	@if [ -z "$$CI" ]; then \
		echo "Checking Docker availability..."; \
		if ! docker info > /dev/null 2>&1; then \
			echo "ERROR: Docker is not running. Please start Docker Desktop and try again."; \
			exit 1; \
		fi; \
		echo "Stopping the server of an earlier run..."; \
		../../integration/example-server.sh stop build/server.pid; \
		echo "Setting up database..."; \
		docker-compose down -v > /dev/null 2>&1 || true; \
		sleep 1; \
		docker-compose up -d postgres > /dev/null 2>&1 || true; \
	else \
		echo "Using CI PostgreSQL service..."; \
	fi
	@if [ -z "$$CI" ]; then \
		echo "Waiting for database to be ready..."; \
		for i in $$(seq 1 30); do \
			if docker-compose exec -T postgres pg_isready -U postgres > /dev/null 2>&1; then \
				echo "Database is ready!"; \
				break; \
			fi; \
			if [ $$i -eq 30 ]; then \
				echo "Database failed to start after 30 seconds"; \
				echo "Checking Docker container status..."; \
				docker-compose ps postgres || true; \
				docker-compose logs --tail=20 postgres || true; \
				docker-compose down; \
				exit 1; \
			fi; \
			sleep 1; \
		done; \
		echo "Running migrations..."; \
		docker-compose exec -T postgres psql -U postgres -c "DROP DATABASE IF EXISTS dream_example_database_db;" > /dev/null 2>&1; \
		docker-compose exec -T postgres psql -U postgres -c "CREATE DATABASE dream_example_database_db;" > /dev/null 2>&1; \
		export DATABASE_URL="$(DATABASE_URL)" && gleam run -m cigogne all || { echo "Migration failed"; docker-compose down; exit 1; }; \
	fi
	echo "Building Gleam application..."; \
	rm -rf build/dev build/prod; \
	output=$$(gleam build 2>&1) || { echo "$$output"; exit 1; }; \
	echo "Checking that src/sql.gleam is the code that dream_sql_generator generates..."; \
	sh test/integration/sql.sh || exit 1; \
	echo "Starting server in background..."; \
	../../integration/run-scenarios.sh database 3002 main http1; \
	FIRST_EXIT=$$?; \
	../../integration/run-scenarios.sh database 3002 tls_main http2; \
	SECOND_EXIT=$$?; \
	if [ -z "$$CI" ]; then \
		docker-compose down > /dev/null 2>&1 || true; \
	fi; \
	[ $$FIRST_EXIT -eq 0 ] && [ $$SECOND_EXIT -eq 0 ]

clean:
	@gleam clean
	@rm -rf coverage
	@rm -f erl_crash.dump
	@find build -name "*.beam" -type f -delete 2>/dev/null || true

# Docker Compose commands for PostgreSQL
# In CI, PostgreSQL is a service of the job, on the same port.
db-up:
	@if [ -n "$$CI" ]; then \
		echo "PostgreSQL runs as a service of the CI job"; \
	else \
		docker-compose up -d postgres; \
		echo "Waiting for PostgreSQL to be ready..."; \
		timeout 30 bash -c 'until docker-compose exec -T postgres pg_isready -U postgres; do sleep 1; done' || true; \
	fi

db-down:
	@docker-compose down

db-logs:
	@docker-compose logs -f postgres

db-shell:
	@docker-compose exec postgres psql -U postgres -d dream_example_database_db

db-reset:
	@docker-compose down -v
	@docker-compose up -d postgres
	@echo "Waiting for PostgreSQL to be ready..."
	@timeout 30 bash -c 'until docker-compose exec -T postgres pg_isready -U postgres; do sleep 1; done' || true

# Migration commands using cigogne
migrate:
	@export DATABASE_URL="$(DATABASE_URL)" && gleam run -m cigogne all

migrate-up:
	@export DATABASE_URL="$(DATABASE_URL)" && gleam run -m cigogne up

migrate-down:
	@export DATABASE_URL="$(DATABASE_URL)" && gleam run -m cigogne down

migrate-new:
	@gleam run -m cigogne new --name $(name)

# Generate src/sql.gleam from the queries in src/sql/ with dream_sql_generator
squirrel:
	@export DATABASE_URL="$(DATABASE_URL)" && gleam run -m dream_sql_generator
