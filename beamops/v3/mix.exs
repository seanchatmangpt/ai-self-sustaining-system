defmodule Beamops.MixProject do
  @moduledoc """
  BEAMOPS v3 - Engineering Elixir Applications Observability Suite
  
  A comprehensive observability platform for BEAM applications following
  Engineering Elixir Applications patterns with Promex + Grafana integration.
  """
  
  use Mix.Project

  def project do
    [
      app: :beamops,
      version: "3.0.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      
      # Documentation
      name: "BEAMOPS v3",
      docs: [
        main: "Beamops",
        extras: ["README.md", "ENGINEERING_PATTERNS.md"],
        groups_for_modules: [
          "Core": [Beamops, Beamops.Application],
          "Promex Integration": [Beamops.Promex, Beamops.Promex.Plugins],
          "BEAM Monitoring": [Beamops.VmMonitor, Beamops.ProcessInspector],
          "Performance": [Beamops.Profiler, Beamops.FlameGraph],
          "Agent Coordination": [Beamops.CoordinationMetrics, Beamops.SasMetrics],
          "Alerting": [Beamops.ErrorTracker, Beamops.AlertEngine],
          "Dashboards": [Beamops.LiveDashboard, Beamops.MetricsVisualizer]
        ]
      ],
      
      # Testing
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application do
    [
      mod: {Beamops.Application, []},
      extra_applications: [:logger, :runtime_tools, :observer, :wx]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Core Observability (Engineering Elixir Applications)
      {:promex, "~> 0.15"},
      {:telemetry, "~> 1.2"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      
      # Phoenix & LiveDashboard
      {:phoenix, "~> 1.8"},
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix_live_dashboard, "~> 0.8"},
      {:phoenix_html, "~> 4.1"},
      
      # OpenTelemetry Integration
      {:opentelemetry, "~> 1.3"},
      {:opentelemetry_api, "~> 1.2"},
      {:opentelemetry_phoenix, "~> 1.1"},
      {:opentelemetry_ecto, "~> 1.1"},
      {:opentelemetry_cowboy, "~> 0.2"},
      {:opentelemetry_process_propagator, "~> 0.2"},
      {:opentelemetry_exporter, "~> 1.6"},
      
      # Performance Profiling
      {:eflambe, "~> 0.3"},
      {:benchee, "~> 1.0"},
      {:observer_cli, "~> 1.7"},
      
      # Error Tracking & Alerting
      {:sentry, "~> 10.0"},
      {:error_tracker, "~> 0.3"},
      {:ex_aws, "~> 2.4"},
      {:ex_aws_sns, "~> 3.0"},
      
      # Database & Storage
      {:jason, "~> 1.4"},
      {:ecto, "~> 3.10"},
      {:postgrex, "~> 0.17"},
      
      # HTTP & Networking
      {:req, "~> 0.5"},
      {:finch, "~> 0.18"},
      {:plug, "~> 1.14"},
      {:plug_cowboy, "~> 2.6"},
      
      # Agent Coordination Integration
      {:nimble_parsec, "~> 1.3"},
      {:libcluster, "~> 3.3"},
      
      # Development & Testing
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:mix_test_watch, "~> 1.1", only: :dev, runtime: false},
      {:ex_machina, "~> 2.7", only: :test},
      {:mox, "~> 1.0", only: :test}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      
      # BEAMOPS specific aliases
      "beamops.start": ["run --no-halt -e Beamops.start_observability()"],
      "beamops.dashboard": ["phx.server"],
      "beamops.profile": ["run -e Beamops.Profiler.interactive_session()"],
      "beamops.metrics": ["run -e Beamops.Promex.export_metrics()"],
      "beamops.health": ["run -e Beamops.HealthChecker.system_health()"],
      
      # Performance analysis
      "perf.flame": ["run -e Beamops.FlameGraph.capture_and_serve()"],
      "perf.bench": ["run benchmarks/coordination_benchmark.exs"],
      "perf.memory": ["run -e Beamops.MemoryAnalyzer.analyze_and_report()"],
      
      # Alert testing
      "alerts.test": ["run -e Beamops.AlertEngine.test_all_alerts()"],
      "alerts.silence": ["run -e Beamops.AlertEngine.silence_all_alerts()"]
    ]
  end
end