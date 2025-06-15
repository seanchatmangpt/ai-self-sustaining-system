import Config

# Configure Ecto repositories
config :self_sustaining, ecto_repos: [SelfSustaining.Repo]

# Configure Ash domains
config :self_sustaining, 
  ash_domains: [SelfSustaining.AIDomain, SelfSustaining.Workflows]

# Disable ash function warnings for now
config :ash, :validate_domain_config_inclusion?, false

# Configure the database
config :self_sustaining, SelfSustaining.Repo,
  database: "self_sustaining_dev",
  username: "root",
  password: "password", 
  hostname: "localhost",
  port: 5434

# Configure the endpoint
config :self_sustaining, SelfSustainingWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "your-secret-key-base-here",
  render_errors: [
    formats: [html: SelfSustainingWeb.ErrorHTML, json: SelfSustainingWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: SelfSustaining.PubSub,
  live_view: [signing_salt: "live-view-salt"]

# Configure esbuild and tailwind
config :esbuild,
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  version: "3.4.0",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configure logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :trace_id, :span_id]

# Configure OpenTelemetry
config :opentelemetry, 
  span_processor: :batch,
  traces_exporter: :console,
  resource: [
    service: [
      name: "self_sustaining_system",
      version: "0.1.0"
    ]
  ]

# Configure OpenTelemetry Phoenix
config :opentelemetry_phoenix, 
  endpoint: SelfSustainingWeb.Endpoint

# Configure OpenTelemetry Ecto  
config :opentelemetry_ecto,
  repos: [SelfSustaining.Repo]

# Configure Oban for background job processing
config :self_sustaining, Oban,
  repo: SelfSustaining.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [default: 10, ash_oban: 5]

# N8N Configuration
config :self_sustaining, :n8n,
  api_url: System.get_env("N8N_API_URL", "http://localhost:5678/api/v1"),
  api_key: System.get_env("N8N_API_KEY", ""),
  webhook_username: System.get_env("N8N_WEBHOOK_USERNAME", "webhook_user"),
  webhook_password: System.get_env("N8N_WEBHOOK_PASSWORD", "webhook_pass"),
  timeout: 30_000

# Import environment specific config
import_config "#{config_env()}.exs"