{:ok, _} = Application.ensure_all_started(:angel)

ExUnit.start()

Mox.defmock(Angel.Graphs.Mock, for: Angel.Graphs.Behaviour)

Ecto.Adapters.SQL.Sandbox.mode(Angel.Repo, :manual)
{:ok, _} = Angel.NonTransactionalRepo.start_link(pool_size: 1)