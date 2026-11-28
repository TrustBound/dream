# The tests of the guide "Load configuration and fail early"

.PHONY: run test format check

# Starts the app with the settings of .env (copy .env.example to .env first)
run:
	@gleam run -m links/main

# Runs the tests. Each startup test runs the app in a new VM with its own
# environment, so the tests need no settings
test:
	@sh scripts/test.sh

format:
	@gleam format

check:
	@gleam check
