# Docker Compose database connection URL
DATABASE_URL = postgres://postgres:postgres@localhost:5435/dream_example_multi_format_db

.PHONY: run test test-integration clean db-up db-down db-logs db-shell db-reset squirrel migrate migrate-up migrate-down migrate-new

run:
	@gleam run -m main

test:
	@gleam test

test-integration:
	@echo "=== Running integration tests ==="
	@if [ -z "$$CI" ]; then \
		echo "Checking Docker availability..."; \
		if ! docker info > /dev/null 2>&1; then \
			echo "ERROR: Docker is not running. Please start Docker Desktop and try again."; \
			exit 1; \
		fi; \
		echo "Killing any existing servers..."; \
		pkill -9 -f "gleam run.*main" 2>/dev/null || true; \
		pkill -9 -f "dream_example_multi_format" 2>/dev/null || true; \
		lsof -ti:3000 | xargs kill -9 2>/dev/null || true; \
		sleep 2; \
		echo "Setting up database..."; \
		docker-compose down -v > /dev/null 2>&1 || true; \
		sleep 1; \
		docker-compose up -d postgres > /dev/null 2>&1 || true; \
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
		docker-compose exec -T postgres psql -U postgres -c "DROP DATABASE IF EXISTS dream_example_multi_format_db;" > /dev/null 2>&1; \
		docker-compose exec -T postgres psql -U postgres -c "CREATE DATABASE dream_example_multi_format_db;" > /dev/null 2>&1; \
		export DATABASE_URL="$(DATABASE_URL)" && gleam run -m cigogne all || { echo "Migration failed"; docker-compose down; exit 1; }; \
	else \
		echo "Using CI PostgreSQL service..."; \
	fi
	echo "Building Gleam application..."; \
	rm -rf build/dev build/prod; \
	gleam build > /dev/null 2>&1; \
	echo "Starting server in background..."; \
	../../integration/run-scenarios.sh multi_format 3000 main http1; \
	FIRST_EXIT=$$?; \
	../../integration/run-scenarios.sh multi_format 3000 tls_main http2; \
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
db-up:
	@docker-compose up -d postgres
	@echo "Waiting for PostgreSQL to be ready..."
	@timeout 30 bash -c 'until docker-compose exec -T postgres pg_isready -U postgres; do sleep 1; done' || true

db-down:
	@docker-compose down

db-logs:
	@docker-compose logs -f postgres

db-shell:
	@docker-compose exec postgres psql -U postgres -d dream_example_multi_format_db

db-reset:
	@docker-compose down -v
	@docker-compose up -d postgres
	@echo "Waiting for PostgreSQL to be ready..."
	@timeout 30 bash -c 'until docker-compose exec -T postgres pg_isready -U postgres; do sleep 1; done' || true

# Generate type-safe SQL code with Squirrel
squirrel:
	@export DATABASE_URL="$(DATABASE_URL)" && gleam run -m squirrel

# Migration commands using cigogne
migrate:
	@export DATABASE_URL="$(DATABASE_URL)" && gleam run -m cigogne all

migrate-up:
	@export DATABASE_URL="$(DATABASE_URL)" && gleam run -m cigogne up

migrate-down:
	@export DATABASE_URL="$(DATABASE_URL)" && gleam run -m cigogne down

migrate-new:
	@gleam run -m cigogne new --name $(name)

