defmodule AshFrameworkDemo.MixProject do
  use Mix.Project

  def project do
    [
      app: :ash_framework_demo,
      version: "2.0.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      mod: {AshFrameworkDemo.Application, []},
      extra_applications: [:logger, :runtime_tools, :opentelemetry, :opentelemetry_exporter]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Phoenix & LiveView
      {:phoenix, "~> 1.7.0"},
      {:phoenix_ecto, "~> 4.4"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.20.2"},
      {:phoenix_live_dashboard, "~> 0.8.0"},
      {:heroicons, "~> 0.5"},
      {:floki, ">= 0.30.0", only: :test},
      
      # Ash Framework - Complete Ecosystem
      {:ash, "~> 3.0"},
      {:ash_postgres, "~> 2.0"},
      {:ash_phoenix, "~> 2.0"},
      {:ash_authentication, "~> 4.0"},
      {:ash_authentication_phoenix, "~> 2.0"},
      {:ash_json_api, "~> 1.0"},
      {:ash_graphql, "~> 1.0"},
      {:ash_oban, "~> 0.4.9"},
      {:ash_archival, "~> 1.0"},
      {:ash_state_machine, "~> 0.2"},
      {:ash_admin, "~> 0.11"},
      
      # Database
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      
      # Background Jobs
      {:oban, "~> 2.17"},
      
      # Telemetry & Observability
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:opentelemetry, "~> 1.3"},
      {:opentelemetry_api, "~> 1.2"},
      {:opentelemetry_exporter, "~> 1.6"},
      {:opentelemetry_phoenix, "~> 1.1"},
      {:opentelemetry_ecto, "~> 1.1"},
      {:opentelemetry_liveview, "~> 1.0.0-rc.4"},
      
      # Utilities
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.5"},
      {:gettext, "~> 0.20"},
      {:httpoison, "~> 2.0"},
      {:cachex, "~> 3.6"},
      
      # Testing & Quality
      {:ex_machina, "~> 2.7", only: [:test, :dev]},
      {:stream_data, "~> 1.0", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.3", only: [:dev], runtime: false}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "ash.setup": ["ash.create", "ash.migrate", "ash.seed"],
      "ash.reset": ["ash.drop", "ash.setup"]
    ]
  end
end