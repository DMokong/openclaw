# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

See also: [AGENTS.md](AGENTS.md) for comprehensive repository guidelines including release processes, security advisories, and operational procedures.

## Project Overview

OpenClaw is a multi-channel AI assistant gateway. The **Gateway** is the WebSocket control plane; everything else (CLI, macOS app, iOS/Android nodes, WebChat, messaging channels) connects to it as clients.

```
Channels (WhatsApp/Telegram/Slack/Discord/Matrix/MS Teams/…)
              │
              ▼
   Gateway (ws://127.0.0.1:18789)
              │
    ├─ Pi agent (RPC)
    ├─ CLI (openclaw …)
    ├─ Control UI / WebChat
    └─ macOS / iOS / Android nodes
```

## Architecture

### Directory Layout

| Path | Purpose |
|------|---------|
| `src/gateway/` | WebSocket control plane — sessions, channels, config, cron, hooks, HTTP endpoints |
| `src/cli/` | CLI option parsing, command wiring, dependency injection via `createDefaultDeps` |
| `src/commands/` | Individual CLI commands |
| `src/channels/` | Channel adapter interfaces and in-tree channels |
| `src/agents/` | Pi agent runtime, tool definitions, session/model management |
| `src/plugin-sdk/` | Public plugin SDK (exported as `openclaw/plugin-sdk`) |
| `src/infra/` | Shared infrastructure: env, ports, formatting utils, binaries, tailscale |
| `src/terminal/` | Terminal output: `renderTable` (table.ts), `theme.*` colors (theme.ts), palette |
| `src/config/` | Config loading, session store, migrations |
| `src/memory/` | Memory / QMD subsystem |
| `src/routing/` | Message routing between channels |
| `src/providers/` | AI model provider integrations |
| `src/media/` | Media pipeline and processing |
| `src/hooks/` | Bundled webhook/hook handlers |
| `src/tui/` | Terminal UI |
| `src/wizard/` | Interactive setup/onboarding flows |
| `src/pairing/` | Device pairing logic |
| `src/security/` | Security subsystem |
| `src/discord/` | Discord channel integration |
| `src/telegram/` | Telegram channel integration |
| `src/slack/` | Slack channel integration |
| `src/signal/` | Signal channel integration |
| `src/imessage/` | iMessage channel integration |
| `src/web/` | WhatsApp Web integration |
| `src/line/` | LINE channel integration |
| `extensions/` | Channel extensions as pnpm workspace packages (38 total) |
| `packages/clawdbot/` | Clawdbot agent package |
| `packages/moltbot/` | Moltbot agent package |
| `apps/macos/` | macOS menu bar app (Swift) |
| `apps/ios/` | iOS node app (Swift) |
| `apps/android/` | Android node app (Kotlin) |
| `apps/shared/` | Shared code between native apps (OpenClawKit) |
| `ui/` | Control UI (Lit web components, served by the Gateway) |
| `docs/` | Documentation (Mintlify-hosted at docs.openclaw.ai) |
| `scripts/` | Build, release, test, and utility scripts |
| `vendor/` | Vendored third-party code (a2ui) |

### Extensions

Channel extensions live under `extensions/` as standalone pnpm workspace packages:

`bluebubbles`, `copilot-proxy`, `device-pair`, `diagnostics-otel`, `discord`, `feishu`, `google-antigravity-auth`, `google-gemini-cli-auth`, `googlechat`, `imessage`, `irc`, `line`, `llm-task`, `lobster`, `matrix`, `mattermost`, `memory-core`, `memory-lancedb`, `minimax-portal-auth`, `msteams`, `nextcloud-talk`, `nostr`, `open-prose`, `phone-control`, `qwen-portal-auth`, `shared`, `signal`, `slack`, `synology-chat`, `talk-voice`, `telegram`, `thread-ownership`, `tlon`, `twitch`, `voice-call`, `whatsapp`, `zalo`, `zalouser`

### Key Architectural Concepts

**Gateway WebSocket protocol** — The gateway (`src/gateway/server.ts`) handles all WS clients. Methods are dispatched from `server-methods.ts`; events flow through `server-chat.ts` and `server-channels.ts`.

**Sessions** — Each conversation has a session key. `main` is the direct-chat session. Groups, agents, and channels each get isolated sessions. Session lifecycle is in `src/gateway/session-utils.ts`.

**Extensions** — Each extension in `extensions/` is a standalone pnpm package that exports a channel or feature plugin. The gateway dynamically loads them via `src/plugins/` and `src/extensionAPI.ts`.

**Plugin SDK** — External plugins use `openclaw/plugin-sdk` (built to `dist/plugin-sdk/`). The SDK types are generated separately via `tsconfig.plugin-sdk.dts.json`.

**Config** — JSON config loaded from `~/.openclaw/`. The gateway hot-reloads config via `src/gateway/config-reload.ts`.

**Agents** — The Pi agent runtime (`@mariozechner/pi-agent-core`) runs in RPC mode. Tool definitions are in `src/agents/tools/`. Agent hooks in `src/agents/` handle streaming, compaction, and model failover.

**Control UI** — The Lit web component UI uses **legacy** decorators (`experimentalDecorators: true`, `useDefineForClassFields: false`). Keep `@state()` / `@property()` in legacy style; do not use `accessor` fields.

## Build, Test, and Development Commands

### Prerequisites

- **Runtime:** Node **22+** (keep Node + Bun paths working)
- **Package manager:** pnpm 10.23.0 (`pnpm-workspace.yaml` defines the monorepo)
- **Also supported:** Bun for TypeScript execution (scripts, dev, tests)

### Common Commands

| Command | Purpose |
|---------|---------|
| `pnpm install` | Install all dependencies |
| `pnpm build` | Full build (tsdown + plugin SDK types + assets) |
| `pnpm check` | Run all checks: format + typecheck + lint |
| `pnpm tsgo` | TypeScript type checking only |
| `pnpm lint` | Oxlint with type-aware rules |
| `pnpm lint:fix` | Auto-fix lint issues + format |
| `pnpm format` | Format with Oxfmt (`--write`) |
| `pnpm format:check` | Check formatting (`--check`) |
| `pnpm test` | Run unit tests (vitest via `scripts/test-parallel.mjs`) |
| `pnpm test:coverage` | Run with V8 coverage |
| `pnpm test:e2e` | End-to-end tests |
| `pnpm test:fast` | Fast unit tests (no gateway/extensions) |
| `pnpm openclaw ...` | Run CLI in dev mode |
| `pnpm dev` | Dev mode shorthand |
| `pnpm ui:dev` | Control UI dev server |
| `pnpm ui:build` | Build Control UI |

### Test Configurations

The test suite uses multiple Vitest configs for different scopes:

| Config | Scope | Notes |
|--------|-------|-------|
| `vitest.config.ts` | Base config | Shared by all others |
| `vitest.unit.config.ts` | Core unit tests | Excludes `src/gateway/**` and `extensions/**` |
| `vitest.gateway.config.ts` | Gateway tests | Only `src/gateway/**/*.test.ts` |
| `vitest.extensions.config.ts` | Extension tests | Only `extensions/**/*.test.ts` |
| `vitest.e2e.config.ts` | End-to-end | Uses `vmForks` pool, `test/**/*.e2e.test.ts` |
| `vitest.live.config.ts` | Live integration | `maxWorkers: 1`, requires `OPENCLAW_LIVE_TEST=1` |

**Coverage thresholds:** 70% lines/functions/statements, 55% branches (core `src/` only).

**Testing conventions:**
- Colocated test files: `*.test.ts` next to source
- E2E tests: `*.e2e.test.ts` in `test/`
- Live tests: `*.live.test.ts` (require real API keys)
- Use `describe`/`it` blocks from Vitest
- Use `vi.fn()`, `vi.mock()`, `vi.stubEnv()` for mocking
- Use `it.each([...])` for parameterized tests
- Use temp directories with cleanup for filesystem tests

### Native App Commands

| Command | Purpose |
|---------|---------|
| `pnpm mac:package` | Package macOS app |
| `pnpm ios:build` | Build iOS app |
| `pnpm ios:open` | Open iOS Xcode project |
| `pnpm android:run` | Build + install + run Android app |
| `pnpm android:test` | Run Android unit tests |

## Coding Conventions

### Language & Module System

- **TypeScript (ESM)** — target ES2023, module NodeNext
- **Strict mode** enabled; avoid `any` (enforced by Oxlint: `typescript/no-explicit-any: "error"`)
- Never add `@ts-nocheck` and do not disable `no-explicit-any`
- Import with `.ts` extensions (enabled by `allowImportingTsExtensions`)

### Formatting & Linting

- **Formatter:** Oxfmt — 2-space indent, no tabs, sorted imports
- **Linter:** Oxlint — type-aware, with plugins: `unicorn`, `typescript`, `oxc`
- Run `pnpm check` before commits (format + typecheck + lint)
- Pre-commit hook auto-runs Oxlint + Oxfmt on staged files

### Style Guidelines

- Keep files under ~500 LOC; split/refactor when it improves clarity
- Add brief code comments for tricky or non-obvious logic
- Use existing patterns for CLI options and dependency injection via `createDefaultDeps`
- CLI progress: use `src/cli/progress.ts` (`osc-progress` + `@clack/prompts` spinner)
- Status output: use `src/terminal/table.ts` for tables with ANSI-safe wrapping
- Colors: use the shared CLI palette in `src/terminal/palette.ts` (no hardcoded colors)
- Never share class behavior via prototype mutation; use explicit inheritance/composition
- Naming: **OpenClaw** for product/app/docs headings; `openclaw` for CLI, package, paths, config keys

### What to Avoid

- Don't add `any` types — fix root causes instead
- Don't edit `node_modules` (including global/Homebrew/npm/git installs)
- Don't update the Carbon dependency
- Don't use `Type.Union` in tool input schemas (no `anyOf`/`oneOf`/`allOf`); use `stringEnum`/`optionalStringEnum`
- Don't use raw `format` property names in tool schemas (reserved by some validators)
- Any dependency with `pnpm.patchedDependencies` must use an exact version (no `^`/`~`)
- Patching dependencies requires explicit approval

## Git & Commit Conventions

### Committing

- Create commits with `scripts/committer "<msg>" <file...>` — avoids staging the entire repo
- Follow concise, action-oriented commit messages (e.g., `CLI: add verbose flag to send`)
- Group related changes; avoid bundling unrelated refactors
- Never commit secrets, real phone numbers, or live config values

### Pre-commit Hook

The pre-commit hook (`git-hooks/pre-commit`) runs automatically:
1. Filters staged files by type (`.ts`, `.tsx`, `.js`, `.jsx`, `.mjs`, `.cjs` for lint; adds `.json`, `.md`, `.mdx` for format)
2. Runs `oxlint --type-aware --fix` on lint-eligible files
3. Runs `oxfmt --write` on format-eligible files
4. Re-stages fixed files

Enable with: `git config core.hooksPath git-hooks` (done automatically by `pnpm install` via the `prepare` script).

## CI/CD Pipeline

The CI pipeline (`.github/workflows/ci.yml`) uses smart scope detection to minimize unnecessary work:

### Jobs

| Job | Trigger | Purpose |
|-----|---------|---------|
| `docs-scope` | Always | Detects docs-only changes to skip heavy jobs |
| `changed-scope` | Non-docs | Detects which areas changed (node/macos/android) |
| `check` | Non-docs | TypeScript types, Oxlint, Oxfmt |
| `checks` | Node changes | Tests (Node + Bun matrix), protocol validation |
| `build-artifacts` | Node changes | Build dist once, share via artifact |
| `release-check` | Push to main | Validate npm pack contents |
| `check-docs` | Docs changed | Format, lint, broken link checks |
| `secrets` | Always | `detect-secrets` scan |
| `checks-windows` | Node changes | Windows-specific test/lint/protocol matrix |
| `macos` | macOS changes | Swift lint + build + test (PR only) |
| `android` | Android changes | Gradle test + build |

### Key CI Details

- Runner: `blacksmith-16vcpu-ubuntu-2404` (Linux), `macos-latest` (macOS)
- Concurrency: cancel-in-progress for PRs
- Tests run with limited workers in CI (2-3) to prevent OOM
- Bun test lane runs on PRs only (skipped on push to main)

## Build System

### tsdown (Build Bundler)

The project uses tsdown for building. Entry points (`tsdown.config.ts`):

| Entry | Output | Purpose |
|-------|--------|---------|
| `src/index.ts` | `dist/index.js` | Main library export |
| `src/entry.ts` | `dist/entry.js` | CLI entry |
| `src/cli/daemon-cli.ts` | `dist/daemon-cli.js` | Legacy CLI shim |
| `src/infra/warning-filter.ts` | `dist/warning-filter.js` | Warning suppression |
| `src/plugin-sdk/index.ts` | `dist/plugin-sdk/index.js` | Plugin SDK |
| `src/plugin-sdk/account-id.ts` | `dist/plugin-sdk/account-id.js` | Account ID module |
| `src/extensionAPI.ts` | `dist/extensionAPI.js` | Extension API |
| `src/hooks/bundled/*/handler.ts` | `dist/hooks/` | Bundled hook handlers |

All entries target Node.js with `NODE_ENV=production` baked in at build time.

### Full Build Pipeline

`pnpm build` runs:
1. `pnpm canvas:a2ui:bundle` — Bundle A2UI canvas assets
2. `tsdown` — Bundle TypeScript
3. `pnpm build:plugin-sdk:dts` — Generate plugin SDK type declarations
4. Several post-build scripts for SDK entries, canvas assets, hook metadata, HTML templates, build info, and CLI compat

## Workspace Structure

Defined in `pnpm-workspace.yaml`:

```yaml
packages:
  - .              # Root (main openclaw package)
  - ui             # Control UI (Lit web components)
  - packages/*     # Agent packages (clawdbot, moltbot)
  - extensions/*   # 38 channel/feature extensions
```

### Plugin/Extension Rules

- Keep plugin-only deps in the extension `package.json`; do not add them to root unless core uses them
- Avoid `workspace:*` in `dependencies` (npm install breaks); use `devDependencies` or `peerDependencies`
- Plugin install runs `npm install --omit=dev` in the plugin dir; runtime deps must be in `dependencies`

## Security

- Never commit or publish real phone numbers, videos, or live configuration values
- Use obviously fake placeholders in docs, tests, and examples
- Web provider credentials: `~/.openclaw/credentials/`
- Pi sessions: `~/.openclaw/sessions/`
- Secret scanning: `detect-secrets` with `.secrets.baseline`

## Documentation

- Hosted on Mintlify at `docs.openclaw.ai`
- Internal doc links: root-relative, no `.md`/`.mdx` (e.g., `[Config](/configuration)`)
- Section cross-references: anchors on root-relative paths (e.g., `[Hooks](/configuration#hooks)`)
- Avoid em dashes and apostrophes in headings (breaks Mintlify anchors)
- Content must be generic: no personal device names/hostnames/paths
- i18n: `docs/zh-CN/**` is generated; do not edit manually

## Multi-Agent Safety

When working alongside other agents:
- Do **not** create/apply/drop `git stash` entries unless explicitly requested
- Do **not** create/remove/modify `git worktree` checkouts
- Do **not** switch branches unless explicitly requested
- When pushing, `git pull --rebase` is OK; never discard others' work
- When committing, scope to your changes only
- Focus reports on your edits; when multiple agents touch the same file, continue if safe
