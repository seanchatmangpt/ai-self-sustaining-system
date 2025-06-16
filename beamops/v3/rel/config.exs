# BeamOps V3 Release Configuration
import Config

config :beamops, BeamopsWeb.Endpoint,
  server: true,
  http: [port: {:system, "PORT", "4000"}],
  url: [host: {:system, "PHX_HOST", "localhost"}, port: {:system, "PHX_PORT", "4000"}]

config :beamops, Beamops.Repo,
  url: {:system, "DATABASE_URL", "ecto://postgres:postgres@localhost/beamops_dev"}

config :logger, level: :info