defmodule Beamops.MixProject do
  @moduledoc """
  BEAMOPS v3 - Engineering Elixir Applications Implementation
  
  Minimal working implementation following Engineering Elixir Applications patterns.
  """
  
  use Mix.Project

  def project do
    [
      app: :beamops,
      version: "3.0.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      mod: {Beamops.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Core Phoenix Framework (minimal)
      {:phoenix, "~> 1.7.0"},
      {:phoenix_live_dashboard, "~> 0.7.2"},
      
      # Observability (Engineering Elixir Applications)
      {:prom_ex, "~> 1.9.0"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      
      # Essential utilities
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.5"},
      
      # Development and testing
      {:floki, ">= 0.30.0", only: :test}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get"]
    ]
  end
end