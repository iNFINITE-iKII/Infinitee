# Infinitee Script Hub

## Gambaran Proyek

Repo ini berisi dua komponen utama:

| Komponen | Lokasi | Stack | Tujuan |
|---|---|---|---|
| **Script Hub Roblox** | `games/ironsoulv1/` | Luau (Roblox) | Cheat/automation script untuk game IronSoul |
| **Discord Bot** | `bot/` | TypeScript + Discord.js v14 + Drizzle ORM | Manajemen lisensi, HWID, tiket |

## Cara Menjalankan

### Discord Bot
- Workflow: **Discord Bot** → `cd bot && node dist/index.mjs`
- Build ulang: `cd bot && npm run build`
- Secret yang dibutuhkan: `DISCORD_BOT_TOKEN`, `DISCORD_CLIENT_ID`, `DISCORD_GUILD_ID`, `NEON_DATABASE_URL`

### Script Roblox (Luau)
- Tidak dijalankan di Replit. File di `games/ironsoulv1/` dieksekusi via exploit executor di Roblox.
- **Jangan validasi** file `.lua` di `games/` dengan `luac` — hanya support Luau-aware tooling.

## Panduan Agen

Baca `AGENT_PROMPT.md` sebelum bekerja di repo ini. Instruksi lengkap ada di sana: struktur modul, aturan Luau, alur kerja standar, dan cara push ke GitHub.

## User Preferences

- Komunikasi dalam **Bahasa Indonesia**.
- Jangan campur dengan Inggris kecuali nama teknis.
- Langsung kerjakan tanpa konfirmasi "boleh lanjut?".
