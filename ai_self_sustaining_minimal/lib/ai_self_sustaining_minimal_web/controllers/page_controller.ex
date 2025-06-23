defmodule AiSelfSustainingMinimalWeb.PageController do
  @moduledoc """
  Primary page controller for the minimal AI self-sustaining system.
  
  Provides the main entry point and system overview for users. This minimal
  controller focuses on essential functionality without complexity theater.
  
  ## Actions
  
  - `home/2` - System homepage with basic status and navigation
  
  ## Design Philosophy
  
  Part of the 80/20 design approach: provides essential user interface
  while avoiding the complexity that contributes to 77.5% information
  loss in the full system.
  """
  
  use AiSelfSustainingMinimalWeb, :controller

  @doc """
  Renders the system homepage.
  
  Provides basic system status, navigation, and entry points to key functionality
  like the coordination dashboard and telemetry monitoring.
  
  ## Parameters
  
  - `conn` - Phoenix connection struct
  - `_params` - Request parameters (unused)
  
  ## Returns
  
  Rendered homepage template with system overview.
  """
  def home(conn, _params) do
    render(conn, :home)
  end
end
