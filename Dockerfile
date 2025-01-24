FROM bitwalker/alpine-elixir-phoenix:latest

WORKDIR /app

COPY mix.exs .
COPY mix.lock .

CMD mix ecto.migrate && mix assets.setup && mix deps.get && mix phx.server

