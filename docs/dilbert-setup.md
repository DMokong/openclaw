# Dilbert Agent Setup

## Why this exists

Dilbert is a persistent, long-running engineering agent. It needs dev tooling
(Go, Ebitengine CGo deps) available inside the gateway container to build and
test projects like Enigma Fauna.

The naive approach is to install tooling at runtime (inside the running container).
That works until the next `openclaw update`, which pulls a fresh image and wipes
everything installed at runtime. This Dockerfile solves that by baking the tooling
into a derived image, so rebuilds don't destroy the dev environment.

### Why not a sandbox?

OpenClaw sandboxes are designed for ephemeral, per-task execution — spawn, run,
die. They are not built to be persistent or stateful. Dilbert needs the opposite:
persistent state, continuity across sessions, and full access to the filesystem
and toolchain. Running a long-lived agent inside a sandbox-on-gateway creates
lifecycle mismatches and loses state on every restart. The gateway container
itself is the right host.

### Why a separate Dockerfile instead of modifying the base?

The base openclaw `Dockerfile` is upstream code — we track it in this fork to stay
close to upstream and pull updates easily. Extending it via `Dockerfile.dilbert`
keeps agent-specific concerns separate. When openclaw ships a new image, you
rebuild the base first, then layer Dilbert's tooling on top in a single step.

---

## What's baked in

- **Go 1.26.0** — auto-detects arm64 vs amd64 at build time
- **Ebitengine CGo deps**: libxrandr-dev, libasound2-dev, libgl1-mesa-dev,
  libxxf86vm-dev, libxi-dev, libxcursor-dev, libxinerama-dev
- **Xvfb** — virtual framebuffer for headless `go test` (Ebitengine/GLFW
  initialises at package `init()` and panics without a display)

---

## Build

```bash
# 1. Build the base openclaw image from source
docker build -t openclaw:local .

# 2. Layer Dilbert tooling on top
docker build -f Dockerfile.dilbert -t openclaw:dilbert .
```

To upgrade Go, pass a build arg — no Dockerfile edit needed:
```bash
docker build -f Dockerfile.dilbert --build-arg GO_VERSION=1.27.0 -t openclaw:dilbert .
```

---

## Run

### Preferred: set OPENCLAW_IMAGE in .env

Add or update this line in your `.env`:
```
OPENCLAW_IMAGE=openclaw:dilbert
```

Then run as normal:
```bash
docker compose up -d
```

Compose reads `OPENCLAW_IMAGE` from `.env` and substitutes it into
`docker-compose.yml`. One stack, one container, no duplication.

### Alternative: compose override file

`docker-compose.dilbert.yml` exists for cases where you want
`docker compose build` to know about `Dockerfile.dilbert` automatically
(e.g. in CI or when scripting the full build+run in one command):

```bash
docker compose -f docker-compose.yml -f docker-compose.dilbert.yml up -d
```

**How compose override merging works:** passing two `-f` files does not create
duplicate services. Compose merges them by service name — the second file only
overrides the keys it specifies (`image`, `build`), everything else (ports,
volumes, environment, command) is inherited from the first file. Result: one
`openclaw-gateway` container with the Dilbert image.

For day-to-day use, the `.env` approach is simpler. The override file is there
if you need it.

---

## Running Go tests (headless)

Ebitengine uses GLFW, which tries to connect to a display at package `init()`.
Without one, tests panic before any test code runs. Xvfb provides a virtual
display:

```bash
Xvfb :99 -screen 0 1280x720x24 &
DISPLAY=:99 go test ./...
```

---

## Updating Go

1. Pass `--build-arg GO_VERSION=x.y.z` at build time, or bump the `ARG GO_VERSION`
   default in `Dockerfile.dilbert`
2. `docker build -f Dockerfile.dilbert -t openclaw:dilbert .`
3. `docker compose up -d` (restarts the container with the new image)

---

## When openclaw releases a new version

```bash
# Pull new source / image
git pull  # (or docker pull, depending on your setup)

# Rebuild base
docker build -t openclaw:local .

# Rebuild Dilbert layer (fast — base layers are cached)
docker build -f Dockerfile.dilbert -t openclaw:dilbert .

# Restart
docker compose up -d
```

The Dilbert layer rebuild is fast because Docker caches the apt and Go install
layers until something in them changes.
