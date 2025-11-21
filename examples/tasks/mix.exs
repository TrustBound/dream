defmodule TasksExample.MixProject do
  use Mix.Project

  def project do
    [
      app: :tasks_example,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      test_paths: ["test/integration"],
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:cucumber, "~> 0.4.1", only: [:test]},
      {:httpoison, "~> 2.0", only: [:test]},
      {:postgrex, "~> 0.19", only: [:test]},
      {:jason, "~> 1.4", only: [:test]}
    ]
  end
end
