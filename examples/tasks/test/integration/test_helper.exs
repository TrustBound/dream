# Load test environment variables
env_test_path = Path.join([__DIR__, "..", "..", ".env.test"])

if File.exists?(env_test_path) do
  File.stream!(env_test_path)
  |> Stream.map(&String.trim/1)
  |> Stream.reject(&(String.starts_with?(&1, "#") or String.trim(&1) == ""))
  |> Enum.each(fn line ->
    case String.split(line, "=", parts: 2) do
      [key, value] -> System.put_env(key, value)
      _ -> :ok
    end
  end)

  IO.puts("✓ Loaded test environment from .env.test")
else
  IO.puts("⚠ Warning: .env.test not found at #{env_test_path}")
  IO.puts("   Tests will use system environment variables")
end

# Load support modules
Code.require_file("support/test_db.ex", __DIR__)
Code.require_file("support/test_helpers.ex", __DIR__)

# Configure Cucumber
feature_pattern =
  case System.get_env("CUCUMBER_FEATURE") do
    nil -> "test/integration/features/**/*.feature"
    feature_file -> feature_file
  end

Application.put_env(:cucumber, :features, [feature_pattern])
Application.put_env(:cucumber, :steps, ["test/integration/features/step_definitions/**/*.exs"])
Application.put_env(:cucumber, :enhanced_error_reporting, true)
Application.put_env(:cucumber, :colors, true)

# Start shared test database connection pool
{:ok, _test_db_pid} = TestDB.start_link()

# Start ExUnit
ExUnit.start(
  formatters: [ExUnit.CLIFormatter],
  colors: [enabled: true],
  trace: true,
  timeout: 10_000
)

# Compile features after everything is loaded
Cucumber.compile_features!()
