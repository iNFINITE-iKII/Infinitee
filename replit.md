# XiFil Hub — Discord Bot

## Overview
Discord bot for license key management (infinitee-bot). Built with discord.js + Drizzle ORM + PostgreSQL (Neon). Includes an HTTP API that serves Lua loader scripts to Roblox games.

## Stack
- **Runtime**: Node.js (ESM)
- **Discord**: discord.js v14
- **Database**: Drizzle ORM + PostgreSQL (Neon)
- **Build**: esbuild (bundles `bot/src/` → `bot/dist/index.mjs`)
- **Logger**: pino / pino-pretty

## Project structure
```
bot/          Discord bot source + compiled dist
  src/        TypeScript source
  dist/       Compiled bundle (index.mjs)
games/        Lua scripts served by the HTTP API
  soul_iron.lua, ironsoulv1.lua, ironsoulbeta.lua, XiFil-Hub.lua
  ironsoulv1/   Module files for ironsoulv1 game
  ironsoulbeta/ Module files for ironsoulbeta game
  soul_iron/    Module files for soul_iron game
```

## How to run
Workflow: **Discord Bot** — `cd bot && node dist/index.mjs`

After code changes, rebuild first:
```
cd bot && npm install && npm run build
```

## Required secrets / env vars
| Variable | Description |
|---|---|
| `DISCORD_BOT_TOKEN` | Discord bot token |
| `DISCORD_CLIENT_ID` | Discord application client ID |
| `NEON_DATABASE_URL` | PostgreSQL connection string (Neon or any Postgres) |
| `DISCORD_GUILD_ID` | Discord server ID (for slash command registration) |
| `TICKET_CHANNEL_ID` | Channel ID where support tickets are created |
| `TICKET_STAFF_ROLE_ID` | Role ID for support staff |
| `LOGGER_CHANNEL_ID` | Channel ID for bot activity logs |
| `PREMIUM_ROLE_NAME` | Name of the premium Discord role |
| `LOADER_URL` | Public URL of the loader endpoint (shown to users in the panel) |
| `SERVER_BASE_URL` | (Optional) Override the base URL injected into Lua files |

## HTTP API endpoints
- `GET /api/lua/loader?game=<name>` — returns the game's Lua loader script
- `GET /api/lua/module/<game>/<path>` — returns a specific Lua module file
- `GET /api/license/check?key=<key>&hwid=<hwid>` — validates a license key
- `GET /health` — health check

## Lua URL patching
The server automatically replaces `https://xifil-hub-production.up.railway.app` in all served Lua files with the current server's URL (derived from request headers or `SERVER_BASE_URL` / `LOADER_URL` env vars). No manual editing of `.lua` files is needed when changing hosting platforms.

## User preferences
