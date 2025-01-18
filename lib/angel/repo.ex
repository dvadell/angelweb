defmodule Angel.Repo do
  use Ecto.Repo,
    otp_app: :angel,
    adapter: Ecto.Adapters.Postgres
end
