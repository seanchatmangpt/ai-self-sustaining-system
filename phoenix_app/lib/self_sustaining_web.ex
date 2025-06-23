defmodule SelfSustainingWeb do
  @moduledoc """
  Web interface entrypoint for the Self-Sustaining AI coordination system.

  Provides common functionality for controllers, LiveView components, and HTML templates
  with built-in distributed tracing support. All web components automatically include
  trace ID handling for request correlation and debugging.

  ## Usage Patterns

  This module is used throughout the web layer with different atoms:

      use SelfSustainingWeb, :controller    # HTTP controllers with trace ID support
      use SelfSustainingWeb, :live_view     # LiveView components with real-time features
      use SelfSustainingWeb, :html          # HTML components and templates
      use SelfSustainingWeb, :router        # Router configuration
      
  ## Built-in Features

  ### Distributed Tracing
  All controllers automatically include `get_trace_id/1` helper for accessing
  the request's trace ID from connection assigns.

  ### Security
  - CSRF protection enabled by default for HTML requests
  - Verified routes for compile-time route checking
  - Secure headers via Phoenix controller helpers

  ### Real-time Capabilities
  - Phoenix LiveView for real-time telemetry dashboards
  - WebSocket support for live system monitoring
  - Live components for interactive system management

  ## Web Components

  - **Controllers**: HTTP request handlers with trace ID support
  - **LiveView**: Real-time interfaces for system monitoring
  - **HTML Components**: Reusable UI components with telemetry integration
  - **Channels**: WebSocket communication (if needed for real-time features)

  ## Development Guidelines

  Keep quoted expressions minimal and focused on imports/aliases only.
  Complex functionality should be defined in separate modules and imported here.
  """

  @doc """
  Defines static asset paths for Phoenix endpoint configuration.

  These paths are served directly by the web server without processing.
  """
  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  @doc """
  Provides router macro for Phoenix routing configuration.

  Includes standard Phoenix router functionality with connection and controller imports.
  """
  def router do
    quote do
      use Phoenix.Router, helpers: false

      # Import common connection and controller functions to use in pipelines
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  @doc """
  Provides channel macro for Phoenix WebSocket channels.

  Enables real-time communication for live system monitoring and agent coordination.
  Used for bidirectional communication between the browser and server.
  """
  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  @doc """
  Provides controller macro with built-in trace ID support.

  Controllers automatically include a `get_trace_id/1` helper function for
  accessing distributed tracing context from connection assigns. All controllers
  support both HTML and JSON formats with automatic layout configuration.
  """
  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: SelfSustainingWeb.Layouts]

      # Helper function to get trace_id from connection
      defp get_trace_id(conn),
        do: conn.assigns[:trace_id] || "trace_#{System.system_time(:nanosecond)}"

      import Plug.Conn
      import SelfSustainingWeb.Gettext

      unquote(verified_routes())
    end
  end

  @doc """
  Provides LiveView macro for real-time web interfaces.

  Configures Phoenix LiveView with the application layout and HTML helpers.
  Used for building interactive telemetry dashboards and system monitoring interfaces.
  """
  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {SelfSustainingWeb.Layouts, :app}

      unquote(html_helpers())
    end
  end

  @doc """
  Provides LiveComponent macro for reusable real-time components.

  Configures Phoenix LiveComponent with HTML helpers for building modular
  UI components that can be embedded in LiveView pages.
  """
  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  @doc """
  Provides HTML component macro for building reusable UI components.

  Configures Phoenix.Component with controller helpers and HTML utilities.
  Used for creating functional components that can be reused across templates.
  """
  def html do
    quote do
      use Phoenix.Component

      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      unquote(html_helpers())
    end
  end

  @doc false
  defp html_helpers do
    quote do
      import Phoenix.HTML
      import Phoenix.HTML.Form
      use PhoenixHTMLHelpers
      import Phoenix.LiveView.Helpers

      import SelfSustainingWeb.CoreComponents
      import SelfSustainingWeb.Gettext

      unquote(verified_routes())
    end
  end

  @doc false
  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: SelfSustainingWeb.Endpoint,
        router: SelfSustainingWeb.Router,
        statics: SelfSustainingWeb.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
