defmodule SelfSustainingWeb.Router do
  use SelfSustainingWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SelfSustainingWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", SelfSustainingWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/health", HealthController, :index
  end

  # API routes
  scope "/api", SelfSustainingWeb do
    pipe_through :api
    
    get "/health", HealthController, :index
    
    # Real Task Management API
    get "/tasks/stats", TaskController, :stats
    resources "/tasks", TaskController, except: [:new, :edit]
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:self_sustaining, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: SelfSustainingWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
