# infinitee-bot

A Discord bot built with TypeScript, discord.js v14, Drizzle ORM, and PostgreSQL (Neon).

## Stack
- Runtime: Node.js (ESM)
- Language: TypeScript (compiled to `bot/dist/`)
- Database: PostgreSQL via Neon (`drizzle-orm` + `drizzle-kit`)
- Bot framework: discord.js v14

## Project structure
```
bot/
  src/        TypeScript source
  dist/       Compiled output (entry: index.mjs)
  drizzle.config.ts
```

## Running the bot
```
cd bot && node dist/index.mjs
```

Workflow: **Discord Bot** — `cd bot && node dist/index.mjs`

## Required environment secrets
| Variable | Purpose |
|---|---|
| `DISCORD_BOT_TOKEN` | Bot token from Discord Developer Portal |
| `DISCORD_CLIENT_ID` | Bot application ID |
| `DISCORD_GUILD_ID` | Guild/server ID for slash command registration |
| `NEON_DATABASE_URL` | PostgreSQL connection string |

## Optional environment variables
`LOGGER_CHANNEL_ID`, `TICKET_CHANNEL_ID`, `TICKET_STAFF_ROLE_ID`, `PREMIUM_ROLE_NAME`, `LOADER_URL`, `SERVER_BASE_URL`

## Development
```
cd bot && npm run dev   # tsx watch (hot reload)
cd bot && npm run build # esbuild compile to dist/
cd bot && npm run db:push # push Drizzle schema to DB
```

## User preferences
- Focus: ironsoulv1 tab farm
