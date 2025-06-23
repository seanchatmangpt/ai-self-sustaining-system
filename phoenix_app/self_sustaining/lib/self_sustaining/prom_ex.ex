defmodule SelfSustaining.PromEx do
  @moduledoc """
  PromEx module for monitoring coordination performance and system health
  """
  use PromEx, otp_app: :self_sustaining

  alias PromEx.Plugins

  @impl true
  def plugins do
    [
      # Built-in PromEx plugins
      Plugins.Application,
      Plugins.Beam,
      {Plugins.Phoenix, router: SelfSustainingWeb.Router, endpoint: SelfSustainingWeb.Endpoint},
      {Plugins.Ecto, repos: [SelfSustaining.Repo]},
      
      # Custom coordination plugin
      SelfSustaining.PromEx.CoordinationPlugin
    ]
  end

  @impl true
  def dashboard_assigns do
    [
      datasource_id: "prometheus-datasource",
      default_selected_interval: "30s"
    ]
  end

  @impl true
  def dashboards do
    [
      {:prom_ex, "application.json"},
      {:prom_ex, "beam.json"},
      {:prom_ex, "phoenix.json"},
      {:prom_ex, "ecto.json"},
      {SelfSustaining.PromEx, "coordination.json"}
    ]
  end
end