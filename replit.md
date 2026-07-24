# infinitee-bot

A Discord bot built with TypeScript + Discord.js v14, using PostgreSQL (Neon) via Drizzle ORM.

## Features
- License key management (generate, delete, renew, revoke, transfer)
- HWID tracking and reset
- Premium sync
- Ticket / panel system
- User key lookups and stats

## Stack
- **Runtime:** Node.js (ESM)
- **Language:** TypeScript (compiled to `dist/` via esbuild)
- **Discord library:** discord.js v14
- **Database:** PostgreSQL via Drizzle ORM (Neon)
- **HTTP server:** lightweight server in `src/server.ts`

## Required secrets
| Secret | Description |
|---|---|
| `DISCORD_BOT_TOKEN` | Bot token from the Discord Developer Portal |
| `DISCORD_CLIENT_ID` | Application ID from the Discord Developer Portal (for slash-command registration) |
| `DISCORD_GUILD_ID` | ID of the Discord server to register commands in |
| `NEON_DATABASE_URL` | PostgreSQL connection string from Neon |

## Optional secrets
| Secret | Description |
|---|---|
| `LOGGER_CHANNEL_ID` | Discord channel ID for bot logs |
| `TICKET_STAFF_ROLE_ID` | Role ID that can see/manage tickets |
| `TICKET_CHANNEL_ID` | Channel ID where ticket transcripts are logged |
| `LOADER_URL` | Override the default loader script URL |
| `SERVER_BASE_URL` | Override the base URL of the HTTP server |
| `PREMIUM_ROLE_NAME` | Name of the premium role (defaults to `PREMIUM`) |

## Running
The bot is pre-built in `dist/`. The configured workflow runs:
```
cd bot && node dist/index.mjs
```

To rebuild after code changes:
```
cd bot && npm run build
```

To push schema changes to the database:
```
cd bot && npm run db:push
```

## User preferences
