# Docker Compose database connection URL
DATABASE_URL = postgres://postgres:postgres@localhost:5437/tasks_db

.PHONY: run test clean db-up db-down db-logs db-shell db-reset squirrel matcha migrate migrate-up migrate-down migrate-new build

run:
	@gleam run -m main

test:
	@gleam test

clean:
	@gleam clean
	@rm -rf coverage
	@rm -f erl_crash.dump
	@find build -name "*.beam" -type f -delete 2>/dev/null || true

# Docker Compose commands for PostgreSQL
db-up:
	@docker-compose up -d
	@echo "Waiting for PostgreSQL to be ready..."
	@timeout 30 bash -c 'until docker-compose exec -T postgres pg_isready -U postgres; do sleep 1; done' || true

db-down:
	@docker-compose down

db-logs:
	@docker-compose logs -f

db-shell:
	@docker-compose exec postgres psql -U postgres -d tasks_db

db-reset:
	@docker-compose down -v
	@docker-compose up -d
	@echo "Waiting for PostgreSQL to be ready..."
	@timeout 30 bash -c 'until docker-compose exec -T postgres pg_isready -U postgres; do sleep 1; done' || true

# Generate type-safe SQL code with Squirrel
squirrel:
	@export DATABASE_URL="$(DATABASE_URL)" && gleam run -m squirrel

# Compile Matcha templates
matcha:
	@matcha

# Migration commands using cigogne
migrate:
	@export DATABASE_URL="$(DATABASE_URL)" && gleam run -m cigogne all

migrate-up:
	@export DATABASE_URL="$(DATABASE_URL)" && gleam run -m cigogne up

migrate-down:
	@export DATABASE_URL="$(DATABASE_URL)" && gleam run -m cigogne down

migrate-new:
	@gleam run -m cigogne new --name $(name)

# Build with matcha and squirrel generation
build: matcha squirrel
	@gleam build

