# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

See also: [AGENTS.md](AGENTS.md) for comprehensive repository guidelines.

## Architecture

OpenClaw is a personal AI assistant gateway. The **Gateway** is the WebSocket control plane; everything else (CLI, macOS app, iOS/Android nodes, WebChat) connects to it as clients.

```
Channels (WhatsApp/Telegram/Slack/Discord/…)
              │
              ▼
   Gateway (ws://127.0.0.1:18789)
              │
    ├─ Pi agent (RPC)
    ├─ CLI (openclaw …)
    ├─ Control UI / WebChat
    └─ macOS / iOS / Android nodes
```

### Directory Layout

| Path | Purpose |
|------|---------|
| `src/gateway/` | WebSocket control plane — sessions, channels, config, cron, hooks, HTTP endpoints |
| `src/cli/` | CLI option parsing, command wiring, dependency injection via `createDefaultDeps` |
| `src/commands/` | Individual CLI commands |
| `src/channels/` | Channel adapter interfaces and in-tree channels (WhatsApp/Telegram/Slack/Discord/…) |
| `src/agents/` | Pi agent runtime, tool definitions, session/model management |
| `src/plugin-sdk/` | Public plugin SDK (exported as `openclaw/plugin-sdk`) |
| `src/infra/` | Shared infrastructure: env, ports, formatting utils, binaries, tailscale |
| `src/terminal/` | Terminal output: `renderTable` (table.ts), `theme.*` colors (theme.ts) |
| `src/config/` | Config loading, session store, migrations |
| `src/memory/` | Memory / QMD subsystem |
| `extensions/` | Optional channel extensions as pnpm workspace packages (37 total: discord, slack, telegram, matrix, msteams, etc.) |
| `packages/clawdbot/` | Clawdbot agent package |
| `packages/moltbot/` | Moltbot agent package |
| `apps/macos/` | macOS menu bar app (Swift) |
| `apps/ios/` | iOS node app (Swift) |
| `apps/android/` | Android node app (Kotlin) |
| `ui/` | Control UI (Lit web components, served by the Gateway) |

### Key Architectural Concepts

**Gateway WebSocket protocol** — The gateway (`src/gateway/server.ts`) handles all WS clients. Methods are dispatched from `server-methods.ts`; events flow through `server-chat.ts` and `server-channels.ts`.

**Sessions** — Each conversation has a session key. `main` is the direct-chat session. Groups, agents, and channels each get isolated sessions. Session lifecycle is in `src/gateway/session-utils.ts`.

**Extensions** — Each extension in `extensions/` is a standalone pnpm package that exports a channel or feature plugin. The gateway dynamically loads them via `src/plugins/` and `src/extensionAPI.ts`.

**Plugin SDK** — External plugins use `openclaw/plugin-sdk` (built to `dist/plugin-sdk/`). The SDK types are generated separately via `tsconfig.plugin-sdk.dts.json`.

**Config** — JSON config loaded from `~/.openclaw/`. The gateway hot-reloads config via `src/gateway/config-reload.ts`.

**Agents** — The Pi agent runtime (`@mariozechner/pi-agent-core`) runs in RPC mode. Tool definitions are in `src/agents/tools/`. Agent hooks in `src/agents/` handle streaming, compaction, and model failover.

**Control UI decorators** — the Lit UI uses **legacy** decorators (`experimentalDecorators: true`, `useDefineForClassFields: false`). Keep `@state()` / `@property()` in legacy style; do not use `accessor` fields.
