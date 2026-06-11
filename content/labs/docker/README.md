# Docker Lab

This lab is one tiny web app. The important files are:

- `Dockerfile` - builds the nginx image.
- `app/index.html` - the page served by nginx.
- `compose.yaml` - starts the lab service on port 8080.

## Quick Path

```bash
docker build -t devman-web:learn .
docker run --rm -p 8080:80 devman-web:learn
docker compose -f compose.yaml up --build
curl http://localhost:8080
docker compose -f compose.yaml logs web
docker compose -f compose.yaml down
```

## Why `docker compose down` may look confusing

Compose only stops containers from the current Compose project. If `docker ps`
shows containers named `devman-web-1` or `devman-redis-1`, those came from the
repo root project at `~/devman/docker-compose.yaml`, not this lab folder.

Stop that root project with:

```bash
cd ~/devman
docker compose down
```

Stop this lab from inside this folder with:

```bash
docker compose -f compose.yaml down
```

Practice logs, exec, rebuilds, cleanup, and write notes in `debug-notes.md`.
