defmodule SelfSustaining.PromEx do
  @moduledoc """
  Agent Coordination Monitoring with PromEx
  Real-time metrics for coordination system performance
  """
  
  use PromEx, otp_app: :self_sustaining

  alias PromEx.Plugin

  @impl true
  def plugins do
    [
      # Built-in PromEx plugins
      Plugin.Application,
      Plugin.Beam,
      Plugin.Phoenix,
      
      # Custom coordination plugin
      SelfSustaining.PromEx.CoordinationPlugin
    ]
  end

  @impl true
  def dashboard_assigns do
    [
      datasource_id: "prometheus",
      default_selected_interval: "30s"
    ]
  end

  @impl true
  def dashboards do
    [
      {:prom_ex, "application.json"},
      {:prom_ex, "beam.json"}, 
      {:prom_ex, "phoenix.json"},
      # Custom coordination dashboard
      {__MODULE__, "coordination.json"}
    ]
  end
end