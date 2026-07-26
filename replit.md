# Infinitee Script Hub

Repo berisi dua komponen utama:

| Komponen | Lokasi | Bahasa |
|---|---|---|
| Script Hub Roblox | `games/ironsoulv1/` | Luau (Roblox) |
| Discord Bot | `bot/` | TypeScript + Discord.js v14 |

## Cara menjalankan Discord Bot

```bash
cd bot && npm run build   # compile TypeScript → dist/
# Workflow: "Discord Bot" → cd bot && node dist/index.mjs
```

Secret yang dibutuhkan: `DISCORD_BOT_TOKEN`, `DISCORD_CLIENT_ID`, `DISCORD_GUILD_ID`, `NEON_DATABASE_URL`

## Script Roblox (Luau)

- Entry point: `games/ironsoulv1.lua` → `games/ironsoulv1/loader.lua`
- **Jangan validasi dengan `luac`** — file adalah Luau, bukan Lua standar
- Untuk cek whitespace conflict: `git diff --check`
- Panduan lengkap ada di `AGENT_PROMPT.md`

## User Preferences

- Fokus utama: `games/ironsoulv1/` — script Roblox IronSoul v1
- Tab prioritas: `games/ironsoulv1/ui/tab_util.lua` (Utilitas)
- Komunikasi dalam Bahasa Indonesia
- Tidak perlu konfirmasi sebelum mengerjakan — langsung kerjakan dan laporkan
