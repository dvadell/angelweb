FROM hexpm/elixir:1.18.4-erlang-25.1.2.1-ubuntu-jammy-20250619

WORKDIR /app

COPY mix.exs .
COPY mix.lock .

RUN mix local.hex --force

RUN apt update
RUN apt install -y npm
RUN apt install -y git

CMD mix deps.get; mix ecto.migrate && mix assets.setup && mix deps.get && mix phx.server

