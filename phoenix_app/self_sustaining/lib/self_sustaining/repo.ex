defmodule SelfSustaining.Repo do
  use Ecto.Repo,
    otp_app: :self_sustaining,
    adapter: Ecto.Adapters.Postgres
end
