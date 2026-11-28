#!/bin/sh
# Runs the tests. "make test" runs this script, and so does the
# integration job of CI. The tests need no settings in the environment.
set -eu

gleam format --check src test
gleam test
