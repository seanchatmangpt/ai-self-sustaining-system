defmodule SelfSustaining.Repo do
  @moduledoc """
  Ecto repository for the SelfSustaining application.

  Provides database access for the AI coordination system with PostgreSQL backend.
  Configured for production-grade performance with connection pooling and telemetry.

  ## Configuration

  Database settings are managed through runtime configuration in config/runtime.exs
  with environment variable overrides for deployment flexibility.

  ## Usage

      alias SelfSustaining.Repo
      
      # Standard Ecto operations
      Repo.get(User, id)
      Repo.insert(changeset)
      Repo.update(changeset)
      
  ## Telemetry

  All database operations are instrumented with telemetry events for monitoring
  query performance and identifying optimization opportunities.
  """

  use Ecto.Repo,
    otp_app: :self_sustaining,
    adapter: Ecto.Adapters.Postgres
end
