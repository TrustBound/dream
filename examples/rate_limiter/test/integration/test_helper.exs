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

# Start ExUnit
ExUnit.start(
  formatters: [ExUnit.CLIFormatter],
  colors: [enabled: true],
  trace: true,
  timeout: 30_000
)

# Compile features after everything is loaded
Cucumber.compile_features!()
