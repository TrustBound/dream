//// Main test entry point using dream_test framework.

import dream_test/reporter/bdd.{report}
import dream_test/runner.{run_all}
import dream_test/unit.{to_test_cases}
import gleam/io
import gleam/list

import advanced_operations_test
import concurrency_test
import config_test
import counter_test
import encoders_test
import error_handling_test
import helpers_test
import persistence_test
import snippets_test
import table_operations_test
import type_safety_test

pub fn main() {
  [
    to_test_cases("config", config_test.tests()),
    to_test_cases("counter", counter_test.tests()),
    to_test_cases("table_operations", table_operations_test.tests()),
    to_test_cases("type_safety", type_safety_test.tests()),
    to_test_cases("error_handling", error_handling_test.tests()),
    to_test_cases("concurrency", concurrency_test.tests()),
    to_test_cases("helpers", helpers_test.tests()),
    to_test_cases("encoders", encoders_test.tests()),
    to_test_cases("persistence", persistence_test.tests()),
    to_test_cases("advanced_operations", advanced_operations_test.tests()),
    to_test_cases("snippets", snippets_test.tests()),
  ]
  |> list.flatten
  |> run_all()
  |> report(io.print)
}
