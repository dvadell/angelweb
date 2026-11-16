# Development with Docker

Everything needed to work on Angel runs in containers, so the host only
needs [Docker Desktop](https://www.docker.com/products/docker-desktop/).

| File | Purpose |
|---|---|
| `Dockerfile.dev` | Ubuntu 24.04 with asdf and the versions in `.tool-versions` (Erlang, Elixir, Node.js), git, `psql`, inotify-tools and Claude Code. Runs as the non-root user `dev`. |
| `docker-compose.dev.yml` | TimescaleDB, the `dev` container and the forecasting service. |
| `docker/dev-start.sh` | The `dev` container's default command: fetches dependencies, creates and migrates the database, and starts Phoenix. |

The existing `Dockerfile` and `docker-compose.yml` (used for deployment) are
not affected.

## Start

```sh
docker compose -f docker-compose.dev.yml up --build
```

The first build compiles Erlang from source and takes a while. When the log
shows `Running AngelWeb.Endpoint`, open <http://localhost:4000/graphs>.

## Work inside the container

In a second terminal:

```sh
docker compose -f docker-compose.dev.yml exec dev bash
```

From that shell:

```sh
mix test                 # the test database is on localhost:5432, as config/test.exs expects
iex -S mix               # console (Phoenix is already running in the main process)
psql postgres://postgres:postgres@localhost:5432/angel
git status
claude                   # Claude Code
```

## Claude Code

Run `claude` in the container and follow the login link the first time. The
login and settings are stored in the `claude_config` volume, so they survive
container restarts and rebuilds.

## Notes

- **Live reload on Windows:** the repository is bind-mounted from the host.
  File changes made from Windows (for example in VS Code on Windows) may not
  reach the container's file watcher, so Phoenix will not reload them
  automatically; restart the `dev` service, or edit from inside the container
  (Claude Code, vim) where reloading works. Cloning the repository inside WSL
  and running compose from there avoids this and is also faster.
- `deps`, `_build` and `assets/node_modules` live in Docker volumes, not in
  your working copy.
- Port 4000 is published on the `db` service because `dev` shares its network
  (that is what puts the database on `localhost` for the tests).

## Reset

```sh
docker compose -f docker-compose.dev.yml down       # stop
docker compose -f docker-compose.dev.yml down -v    # stop and delete the database, deps, build and Claude login
```
