FROM hexpm/elixir:1.18.2-erlang-27.2.1-debian-buster-20240612

WORKDIR /app

COPY mix.exs .
COPY mix.lock .

RUN mix local.hex --force

RUN apt update
RUN apt install -y npm
RUN apt install -y git

CMD mix deps.get; mix ecto.migrate && mix assets.setup && mix deps.get && mix phx.server

