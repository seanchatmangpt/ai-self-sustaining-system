defmodule SelfSustaining.MixProject do
  use Mix.Project

  def project do
    [
      app: :self_sustaining,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      mod: {SelfSustaining.Application, []},
      extra_applications: [
        :logger,
        :runtime_tools,
        :opentelemetry,
        :opentelemetry_exporter,
        :os_mon
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.7.0"},
      {:phoenix_ecto, "~> 4.4"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_html_helpers, "~> 1.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.20.2"},
      {:phoenix_live_dashboard, "~> 0.8.0"},
      {:heroicons, "~> 0.5"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.20"},
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.5"},

      # Ash Framework
      {:ash, "~> 3.0"},
      {:ash_postgres, "~> 2.0"},
      {:ash_phoenix, "~> 2.0"},
      {:ash_authentication, "~> 4.0"},
      {:ash_authentication_phoenix, "~> 2.0"},
      {:ash_oban, "~> 0.4.9"},
      {:oban, "~> 2.17"},
      {:ash_ai, github: "ash-project/ash_ai"},

      # Reactor for workflow orchestration
      {:reactor, "~> 0.15.4"},

      # Additional dependencies
      {:tidewave, "~> 0.1"},
      {:httpoison, "~> 2.0"},
      {:req, "~> 0.5.2"},
      {:file_system, "~> 1.0"},
      {:cachex, "~> 3.6"},
      {:yaml_elixir, "~> 2.9"},

      # OpenTelemetry - using compatible versions
      {:opentelemetry, "~> 1.3"},
      {:opentelemetry_api, "~> 1.2"},
      {:opentelemetry_exporter, "~> 1.6"},
      {:opentelemetry_phoenix, "~> 1.1"},
      {:opentelemetry_ecto, "~> 1.1"},
      {:opentelemetry_cowboy, "~> 0.2"},
      {:opentelemetry_liveview, "~> 1.0.0-rc.4"},

      # PromEx for Prometheus metrics
      {:prom_ex, "~> 1.9.0"},

      # Asset compilation
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev}

      # Livebook Teams Integration (optional - install separately)
      # {:livebook, "~> 0.12.0", optional: true},
      # {:kino, "~> 0.12.0", optional: true},
      # {:kino_vega_lite, "~> 0.1.8", optional: true},
      # {:kino_db, "~> 0.2.5", optional: true},
      # {:vega_lite, "~> 0.1.7", optional: true},
      # {:explorer, "~> 0.7.0", optional: true},
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind default", "esbuild default"],
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"]
    ]
  end
end
