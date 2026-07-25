# Infinitee Script Hub

Repo ini berisi dua komponen utama:

| Komponen | Lokasi | Bahasa | Tujuan |
|---|---|---|---|
| **Script Hub Roblox** | `games/ironsoulv1/` | Luau (Roblox) | Cheat/automation script untuk game IronSoul v1 |
| **Discord Bot** | `bot/` | TypeScript + Discord.js v14 | Manajemen lisensi, HWID, tiket |

## Cara Menjalankan

### Discord Bot
- Workflow: `cd bot && node dist/index.mjs`
- Rebuild: `cd bot && npm run build`
- Secrets yang dibutuhkan: `DISCORD_BOT_TOKEN`, `NEON_DATABASE_URL`
- Env vars yang sudah di-set: `DISCORD_CLIENT_ID`, `DISCORD_GUILD_ID`

### Roblox Script
- File Luau di `games/ironsoulv1/` — dijalankan di lingkungan Roblox, bukan Replit
- Entry point: `games/ironsoulv1/loader.lua`

## Git & GitHub
- Remote: `https://github.com/iNFINITE-iKII/Infinitee`
- Branch utama: `main`
- Push menggunakan secret `GITHUB_PERSONAL_ACCESS_TOKEN` via Basic auth

## User Preferences

- **Bahasa komunikasi**: Indonesia penuh. Nama teknis (function, variable, file path) boleh Inggris.
- **Nada**: Profesional tapi tidak kaku. Langsung ke inti.
- **Tidak perlu** konfirmasi "apakah saya boleh lanjut?" — langsung kerjakan dan laporkan hasilnya.
- Saat menjelaskan bug: tampilkan root cause → alur lama (❌) → alur baru (✅)
- Saat push berhasil: tampilkan ringkasan (hash, branch, remote, status sinkron)
- Saat implementasi fitur: jelaskan 2–4 kalimat + snippet kode yang berubah + file yang diubah
- Jangan gunakan `luac` untuk validasi file Luau di `games/` — gunakan `git diff --check`
- Jangan `git push --force` kecuali diminta eksplisit
- Toggle baru di Roblox script wajib ditambahkan ke `SyncAllVisualUI` (ui_sync.lua)
