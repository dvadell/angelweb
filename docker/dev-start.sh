#!/usr/bin/env bash
# Default command of the dev container: install dependencies, prepare the
# database and start Phoenix on port 4000.
set -euo pipefail

# Named volumes may be created root-owned
sudo chown -R dev:dev /app/deps /app/_build /app/assets/node_modules /home/dev/.claude

mix deps.get
npm install --prefix assets
mix assets.setup
mix ecto.create -r Angel.Repo
mix ecto.migrate -r Angel.Repo

exec mix phx.server
