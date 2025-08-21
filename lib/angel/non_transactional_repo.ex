defmodule Angel.NonTransactionalRepo do
  @moduledoc "Angel NonTransactionalRepo for tests that need to wait"
  use Ecto.Repo, otp_app: :angel, adapter: Ecto.Adapters.Postgres
end
