# Docker Compose database connection URL
DATABASE_URL = postgres://postgres:postgres@localhost:5437/tasks_db

.PHONY: run test test-integration test-e2e e2e-install e2e-open e2e-run e2e-test e2e-clean clean db-up db-down db-logs db-shell db-reset squirrel matcha migrate migrate-up migrate-down migrate-new build

run:
	@export DATABASE_URL="$(DATABASE_URL)" && gleam run -m main

test:
	@gleam test

test-integration:
	@echo "=== Running integration tests ==="
	@echo "Killing any existing servers..."
	@pkill -9 -f "gleam run.*main" 2>/dev/null || true
	@pkill -9 -f "tasks_example" 2>/dev/null || true
	@lsof -ti:3000 | xargs kill -9 2>/dev/null || true
	@sleep 1
	@echo "Starting database..."
	@make db-up > /dev/null 2>&1 || true
	@echo "Running migrations..."
	@export DATABASE_URL="$(DATABASE_URL)" && make migrate > /dev/null 2>&1
	@echo "Generating SQL code..."
	@export DATABASE_URL="$(DATABASE_URL)" && make squirrel > /dev/null 2>&1
	@echo "Compiling matcha templates..."
	@make matcha > /dev/null 2>&1
	@echo "Building Gleam application..."
	@make clean > /dev/null 2>&1 || true
	@make build > /dev/null 2>&1
	@echo "Starting server in background..."
	@export DATABASE_URL="$(DATABASE_URL)" && gleam run -m main > /tmp/tasks_test.log 2>&1 &
	@SERVER_PID=$$!; \
	echo "Waiting for server to be ready..."; \
	for i in $$(seq 1 30); do \
		if curl -s http://localhost:3000/ > /dev/null 2>&1; then \
			echo "Server is ready!"; \
			break; \
		fi; \
		if [ $$i -eq 30 ]; then \
			echo "Server failed to start"; \
			tail -20 /tmp/tasks_test.log; \
			kill $$SERVER_PID 2>/dev/null || true; \
			make db-down > /dev/null 2>&1 || true; \
			exit 1; \
		fi; \
		sleep 1; \
	done; \
	echo "Running Cucumber tests..."; \
	export DATABASE_URL="$(DATABASE_URL)"; \
	mix deps.get > /dev/null 2>&1 && MIX_ENV=test mix test; \
	TEST_EXIT=$$?; \
	echo "Stopping server..."; \
	kill $$SERVER_PID 2>/dev/null || true; \
	make db-down > /dev/null 2>&1 || true; \
	exit $$TEST_EXIT

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
	@export DATABASE_URL="$(DATABASE_URL)" && make migrate > /dev/null 2>&1 || true

create-project-in-db:
	@export DATABASE_URL="$(DATABASE_URL)" && docker-compose exec -T postgres psql -U postgres -d tasks_db -c "INSERT INTO projects (name, description, created_at) VALUES ('$(NAME)', 'Test project', NOW()) RETURNING id;" || true

create-task-in-db:
	@export DATABASE_URL="$(DATABASE_URL)" && docker-compose exec -T postgres psql -U postgres -d tasks_db -c "INSERT INTO tasks (title, description, completed, priority, due_date, position, project_id, created_at, updated_at) VALUES ('$(TITLE)', '', false, 3, NULL, 0, $(PROJECT_ID), NOW(), NOW()) RETURNING id;" || true

create-tag-in-db:
	@export DATABASE_URL="$(DATABASE_URL)" && docker-compose exec -T postgres psql -U postgres -d tasks_db -c "INSERT INTO tags (name, created_at) VALUES ('$(NAME)', NOW()) RETURNING id;" || true

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

# E2E Testing with Cypress
e2e-install:
	@echo "Installing Cypress and dependencies..."
	@npm install

e2e-open:
	@echo "Opening Cypress Test Runner..."
	@npx cypress open

e2e-run:
	@echo "Running Cypress E2E tests..."
	@npx cypress run --config video=false

e2e-test:
	@echo "=== Running E2E tests ==="
	@echo "Installing dependencies..."
	@npm install > /dev/null 2>&1 || true
	@echo "Killing any existing servers..."
	@pkill -9 -f "gleam run.*main" 2>/dev/null || true
	@pkill -9 -f "tasks_example" 2>/dev/null || true
	@lsof -ti:3000 | xargs kill -9 2>/dev/null || true
	@sleep 1
	@echo "Starting database..."
	@make db-up > /dev/null 2>&1 || true
	@echo "Running migrations..."
	@export DATABASE_URL="$(DATABASE_URL)" && make migrate > /dev/null 2>&1
	@echo "Generating SQL code..."
	@export DATABASE_URL="$(DATABASE_URL)" && make squirrel > /dev/null 2>&1
	@echo "Compiling matcha templates..."
	@make matcha > /dev/null 2>&1
	@echo "Building Gleam application..."
	@make clean > /dev/null 2>&1 || true
	@make build > /dev/null 2>&1
	@echo "Starting server in background..."
	@export DATABASE_URL="$(DATABASE_URL)" && gleam run -m main > /tmp/tasks_e2e.log 2>&1 &
	@SERVER_PID=$$!; \
	echo "Waiting for server to be ready..."; \
	for i in $$(seq 1 30); do \
		if curl -s http://localhost:3000/ > /dev/null 2>&1; then \
			echo "Server is ready!"; \
			break; \
		fi; \
		if [ $$i -eq 30 ]; then \
			echo "Server failed to start"; \
			tail -20 /tmp/tasks_e2e.log; \
			kill $$SERVER_PID 2>/dev/null || true; \
			make db-down > /dev/null 2>&1 || true; \
			exit 1; \
		fi; \
		sleep 1; \
	done; \
	echo "Running Cypress E2E tests..."; \
	npm run test:e2e; \
	TEST_EXIT=$$?; \
	echo "Stopping server..."; \
	kill $$SERVER_PID 2>/dev/null || true; \
	make db-down > /dev/null 2>&1 || true; \
	exit $$TEST_EXIT

e2e-clean:
	@echo "Cleaning Cypress artifacts..."
	@rm -rf cypress/screenshots
	@rm -rf cypress/videos
	@rm -rf cypress/downloads

