# Docker Cheat Sheet

## Goal

Build an image, run it, inspect it, stop it, and understand which Compose project
owns each container.

## Where Am I?

Run these first:

```bash
pwd
ls
cat README.md
```

You should see `Dockerfile`, `compose.yaml`, and `app/index.html`.

## Single Container Path

```bash
docker build -t devman-web:learn .
docker run --rm -p 8080:80 devman-web:learn
curl http://localhost:8080
```

Press `Ctrl+C` to stop that foreground container.

## Compose Path

```bash
docker compose -f compose.yaml up --build
docker compose -f compose.yaml ps
docker compose -f compose.yaml logs web
docker compose -f compose.yaml down
```

## If `docker ps` Still Shows Containers

Run:

```bash
docker compose ls --all
```

If you see project `devman` using `/home/ahmed/devman/docker-compose.yaml`, stop
that root project:

```bash
cd ~/devman
docker compose down
```

Then go back to the lab:

```bash
cd ~/devman/devman-lab-docker
```

## Done Looks Like

`devman learn validate docker .` passes, `curl http://localhost:8080` works while
Compose is up, and `docker ps` is clean after `down`.
