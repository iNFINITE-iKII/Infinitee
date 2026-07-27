# Infinitee Script Hub

Repo ini berisi dua komponen utama:

| Komponen | Lokasi | Bahasa | Tujuan |
|---|---|---|---|
| **Script Hub Roblox** | `games/ironsoulv1/` | Luau (Roblox) | Script automation untuk game IronSoul v1 |
| **Discord Bot** | `bot/` | TypeScript + Discord.js v14 | Manajemen lisensi, HWID, tiket |

## Deployment Discord Bot

Bot ini ditujukan untuk dijalankan di **Railway** dengan database **Neon**, bukan sebagai
workflow runtime di Replit.

1. Hubungkan repository ke Railway dan gunakan `railway.toml` yang tersedia.
2. Set variable di Railway: `DISCORD_BOT_TOKEN`, `DISCORD_CLIENT_ID`,
   `DISCORD_GUILD_ID`, dan `NEON_DATABASE_URL` dari Neon.
3. Railway akan menjalankan install dependency dari npm publik dan `npm run build`,
   lalu menjalankan `cd bot && npm start`. Build sengaja tidak memakai lockfile hasil
   import yang menunjuk ke registry internal Replit.

## Struktur IronSoul v1

```
games/ironsoulv1/
├── core.lua          — Services, EngineConfig, konstanta global
├── loader.lua        — Entry point, urutan load semua modul
├── init.lua          — Inisialisasi Hub (getgenv().Hub)
├── farm.lua          — Auto Farm loop (Egg / Chest / Monster)
├── combat.lua        — GetPositionCFrame(), CombatEngine
├── navigation.lua    — Navigasi antar room/world
├── auto_potion.lua   — Sistem Auto Buff Potion
├── auto_forge.lua    — Auto Forge
├── buff_card.lua     — Auto Buff Card
├── config_system.lua — Save/Load profil ke JSON
├── ui_sync.lua       — SyncAllVisualUI()
├── notify.lua        — CustomNotify()
├── maid.lua          — Lifecycle / cleanup connections
├── npc_scanner.lua   — Scanner NPC/monster
├── translate.lua     — Sistem terjemahan label UI
└── ui/               — Semua tab UI (farm, potion, sell, dll.)
```

## Catatan Penting

- File `.lua` di `games/` adalah **Luau** (Roblox) — jangan validasi dengan `luac` standar
- Semua modul berbagi data lewat `getgenv().Hub` (disingkat `H`)
- Saat menambah toggle baru: wajib tambahkan key di `EngineConfig` (core.lua) DAN `SetValue` di `SyncAllVisualUI` (ui_sync.lua)
- Panduan lengkap ada di `AGENT_PROMPT.md`

## User Preferences

- Fokus utama: IronSoul v1 (`games/ironsoulv1/`)
- Komunikasi dalam Bahasa Indonesia
- Nada profesional, langsung ke inti
- Baca `AGENT_PROMPT.md` sebelum mengerjakan IronSoul
