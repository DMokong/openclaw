# Dilbert Agent Setup

Dilbert is a persistent, long-running engineering agent that runs directly in the
OpenClaw gateway container. This document covers how to build and run the
Dilbert-specific image, which extends the base openclaw image with development
tooling for projects like Enigma Fauna.

## What's included

- **Go 1.26.0** (linux/arm64 and linux/amd64)
- **Ebitengine CGo deps**: libxrandr, libasound2, libgl1-mesa, libxxf86vm, libxi, libxcursor, libxinerama
- **Xvfb**: virtual framebuffer for headless `go test` runs (Ebitengine/GLFW requires a display)

## Build

```bash
# Step 1: build the base openclaw image (if not already done)
docker build -t openclaw:local .

# Step 2: build the Dilbert image on top
docker build -f Dockerfile.dilbert -t openclaw:dilbert .
```

To pin or upgrade Go:
```bash
docker build -f Dockerfile.dilbert --build-arg GO_VERSION=1.26.0 -t openclaw:dilbert .
```

## Run

Use the compose override to swap the gateway image:

```bash
docker compose -f docker-compose.yml -f docker-compose.dilbert.yml up -d
```

Or set `OPENCLAW_IMAGE=openclaw:dilbert` in your `.env` and use the base compose file as-is.

## Running tests (headless)

Inside the container, tests that use Ebitengine require a virtual display:

```bash
Xvfb :99 -screen 0 1280x720x24 &
DISPLAY=:99 go test ./...
```

## Updating Go

1. Bump `GO_VERSION` in `Dockerfile.dilbert` (or pass `--build-arg GO_VERSION=x.y.z`)
2. Rebuild: `docker build -f Dockerfile.dilbert -t openclaw:dilbert .`
3. Restart the gateway container

## Architecture

- Dilbert is a **persistent agent**, not an ephemeral subagent
- Runs directly in the gateway container — not in a sandbox
- Has full filesystem access and root in the container
- State lives in the mounted workspace volume (`/home/node/.openclaw/workspace-dilbert`)
  and survives container restarts
- **Note:** tooling installed via the image survives image rebuilds;
  tooling installed at runtime does not
