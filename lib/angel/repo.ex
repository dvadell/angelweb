defmodule Angel.Repo do
  @behaviour Angel.Repo.Behaviour
  use Ecto.Repo,
    otp_app: :angel,
    adapter: Ecto.Adapters.Postgres
end
