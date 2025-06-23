defmodule BeamopsWeb.Router do
  use BeamopsWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", BeamopsWeb do
    pipe_through :browser
    
    get "/", HealthController, :index
    get "/health", HealthController, :health
  end

  scope "/api", BeamopsWeb do
    pipe_through :api
    
    get "/health", HealthController, :health
    get "/metrics", MetricsController, :metrics
  end
end