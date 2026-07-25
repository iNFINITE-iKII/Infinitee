# Agent Prompt — Infinitee Script Hub

> File ini adalah instruksi untuk agen AI yang bekerja di repo ini.
> Baca seluruhnya sebelum merespons atau menyentuh kode apapun.

---

## 1. Identitas Proyek

Repo ini berisi dua komponen utama:

| Komponen | Lokasi | Bahasa | Tujuan |
|---|---|---|---|
| **Script Hub Roblox** | `games/ironsoulv1/` | Luau (Roblox) | Cheat/automation script untuk game IronSoul v1 |
| **Discord Bot** | `bot/` | TypeScript + Discord.js v14 | Manajemen lisensi, HWID, tiket |

Pemilik proyek adalah developer Indonesia. **Seluruh komunikasi dilakukan dalam Bahasa Indonesia.**

---

## 2. Bahasa & Gaya Respons

### Wajib diikuti di setiap respons:

- **Bahasa**: Indonesia penuh. Jangan campur dengan Inggris kecuali nama teknis (function, variable, file path, dll.).
- **Nada**: Profesional tapi tidak kaku. Langsung ke inti, tidak bertele-tele.
- **Tidak perlu** konfirmasi "apakah saya boleh lanjut?" — langsung kerjakan dan laporkan hasilnya.

### Format respons saat **menjelaskan bug**:

Selalu tunjukkan **root cause** dulu, lalu **alur yang salah**, lalu **alur yang benar setelah fix**.

Contoh format yang disukai:

```
**Root cause:**
[Penjelasan singkat satu paragraf tentang apa yang salah dan mengapa]

❌ URUTAN LAMA
1. Langkah A → hasilnya salah karena [alasan]
2. Langkah B → sudah terlambat

✅ URUTAN BARU
1. Langkah B dulu → data sudah benar
2. Langkah A → sekarang bekerja
```

### Format respons saat **push ke GitHub**:

Setelah push berhasil, selalu tampilkan ringkasan singkat:

```
Push berhasil. Commit: `<hash>`.

- Branch: `main`
- Remote: `origin/main`
- Commit: `<hash>`
- Status: lokal dan remote sudah sinkron.
```

### Format respons saat **implementasi fitur**:

- Jelaskan perubahan dalam 2–4 kalimat
- Tampilkan snippet kode relevan yang berubah (bukan seluruh file)
- Sebutkan file yang diubah

---

## 3. Struktur Kode — `games/ironsoulv1/`

```
games/ironsoulv1/
├── core.lua          — Services, EngineConfig (semua toggle & config), konstanta global
├── loader.lua        — Entry point, urutan load semua modul
├── init.lua          — Inisialisasi Hub (getgenv().Hub)
├── farm.lua          — Farm loop: Auto Farm Egg / Chest / Monster
├── combat.lua        — GetPositionCFrame(), GetValidMonsters(), CombatEngine
├── navigation.lua    — Navigasi antar room/world
├── auto_potion.lua   — Sistem Auto Buff Potion
├── auto_forge.lua    — Auto Forge
├── buff_card.lua     — Auto Buff Card
├── config_system.lua — Save/Load profil ke file JSON (writefile/readfile)
├── ui_sync.lua       — SyncAllVisualUI(): sinkronisasi semua toggle UI setelah load profil
├── notify.lua        — CustomNotify()
├── maid.lua          — Lifecycle / cleanup connections
├── npc_scanner.lua   — Scanner NPC/monster
├── translate.lua     — Sistem terjemahan label UI
└── ui/
    ├── ui_core.lua         — Library UI: CreateToggleUI, CreateDropdownUI, dll.
    ├── tab_farm.lua        — Tab Auto Farm (toggle monster/chest/egg, FarmPosition)
    ├── tab_autopotion.lua  — Tab Auto Potion (master toggle + list potion)
    ├── tab_autobuy.lua     — Tab Auto Buy
    ├── tab_forge.lua       — Tab Auto Forge
    ├── tab_room.lua        — Tab Room (world, mode, room target)
    ├── tab_profile.lua     — Tab profil (save/load/autoload)
    ├── tab_sell.lua        — Tab Auto Sell
    ├── tab_util.lua        — Tab utilitas (lottery, race reroll, kode)
    ├── tab_vector.lua      — Tab Fly / Vector
    ├── tab_npc.lua         — Tab NPC scanner
    └── tab_visual.lua      — Tab visual (tema, font, transparansi)
```

### Variabel penting di `EngineConfig` (core.lua):

| Key | Tipe | Fungsi |
|---|---|---|
| `AutoFarmActive` | bool | Master toggle Auto Farm |
| `FarmTargetEgg` | bool | Toggle target DragonEgg |
| `FarmTargetChest` | bool | Toggle target Chest |
| `FarmTargetMonster` | bool | Toggle target Monster |
| `AutoPotionActive` | bool | Master toggle Auto Potion |
| `AutoPotionSelected` | table | map: PotionId → bool |
| `FarmPosition` | string | "Top" / "Bottom" / dll. |
| `SelectedWeapon` | string | "Heavy" / "Bow" |
| `AutoSkillActive` | bool | Toggle Auto Skill |

### Pola Hub (getgenv):

Semua modul berbagi data lewat `getgenv().Hub` (disingkat `H`). Contoh:

```lua
local H = getgenv().Hub
local EngineConfig = H.EngineConfig
local Services     = H.Services
local CustomNotify = H.CustomNotify
```

---

## 4. Aturan Kode Luau

- File ini adalah **Luau** (Roblox), bukan Lua standar.
- Sintaks Luau yang boleh dipakai: `continue`, conditional types, `task.*`, `bit32`, dll.
- **Jangan validasi** file `.lua` di folder `games/` dengan `luac` standar — akan selalu error karena sintaks Luau.
- Untuk cek whitespace/conflict: gunakan `git diff --check` saja.
- Semua file ditulis dengan encoding **UTF-8**, komentar dalam **Bahasa Indonesia**.
- Blok kode selalu diawali header section:
  ```lua
  --------------------------------------------------------------------------------
  --// nama_file.lua — S## Deskripsi Section
  --------------------------------------------------------------------------------
  ```

---

## 5. Sistem Save/Load Profil

- **Save**: `ConfigSystem.SaveNew(name)` → encode seluruh `EngineConfig` ke JSON → tulis ke `XiFilHub_Configs/<name>.json`
- **Load**: `ConfigSystem.Load(name, callback)` → baca JSON → loop `for k,v in pairs(data) do EngineConfig[k]=v end` → panggil `callback()` (yaitu `SyncAllVisualUI`)
- **UI Sync**: `SyncAllVisualUI()` di `ui_sync.lua` — sinkronkan semua toggle/dropdown ke nilai `EngineConfig` yang baru di-load

### Aturan kritis saat menambah toggle baru:

1. Tambahkan key di `EngineConfig` (core.lua) dengan nilai default
2. Tambahkan `SetValue` di `SyncAllVisualUI` (ui_sync.lua)
3. Jika toggle punya side effect (misal mengaktifkan engine), **relink data dulu** sebelum `SetValue` agar callback tidak membaca data lama

---

## 6. Sistem UI Toggle

`CreateToggleUI` di `ui_core.lua` mengembalikan API dengan `SetValue(val)`.

**PENTING**: `SetValue` **selalu memanggil callback** (`pcall(callback, val)`).
Artinya saat `SyncAllVisualUI` memanggil `toggle:SetValue(x)`, callback toggle ikut terpicu.
Jika callback membaca state lain (misal tabel selected), state itu harus sudah diperbarui **sebelum** `SetValue` dipanggil.

---

## 7. Sistem Auto Farm Egg

### Konstanta siklus (farm.lua):
```lua
EGG_CYCLE_DURATION       = 5.0   -- total siklus
EGG_CYCLE_ABOVE_DURATION = 0.7   -- Fase 1: Y +5
EGG_CYCLE_BELOW_DURATION = 1.3   -- Fase 2: Y -5
-- Fase 3: 3.0 detik di FarmPosition
```

### Arsitektur siklus posisi:
Siklus posisi 5 detik berjalan di **thread terpisah** (`task.spawn` di dalam `startFarmLoop`), bukan di main loop. Ini memastikan siklus terus berjalan selama cooldown 12 detik setelah trigger egg.

Thread siklus menggunakan `task.wait()` nyata per fase:
- `task.wait(0.7)` → Fase 1
- `task.wait(1.3)` → Fase 2
- loop `task.wait(0.5)` × 6 → Fase 3

Thread berhenti saat `_farmLoopRunning == false`.

### Trigger egg:
- `ProximityPrompt` (utama) — selalu digunakan jika ada
- `VirtualInputManager:SendKeyEvent(F)` (fallback PC) — hanya di non-mobile
- Mobile dideteksi: `TouchEnabled == true AND KeyboardEnabled == false`
- Cooldown: 12 detik setelah trigger; siklus posisi tetap jalan selama cooldown

---

## 8. Git & GitHub

- Remote: `https://github.com/iNFINITE-iKII/Infinitee`
- Branch utama: `main`
- **Selalu push normal** (jangan `--force` kecuali diminta eksplisit)
- Token push menggunakan secret `GITHUB_PERSONAL_ACCESS_TOKEN` via Basic auth:

```bash
basic=$(printf 'x-access-token:%s' "$GITHUB_PERSONAL_ACCESS_TOKEN" | base64 -w0)
git -c credential.helper= -c "http.extraheader=AUTHORIZATION: Basic ${basic}" push origin main
```

- Setelah push, selalu verifikasi dengan `git log -1 --oneline` dan `git status --short`
- Pesan commit: singkat, deskriptif, Inggris (konvensi standar Git)

---

## 9. Discord Bot (`bot/`)

- Runtime: Node.js ESM, TypeScript dikompilasi ke `dist/` via esbuild
- Workflow: `cd bot && node dist/index.mjs`
- Rebuild: `cd bot && npm run build`
- Secret yang dibutuhkan: `DISCORD_BOT_TOKEN`, `DISCORD_CLIENT_ID`, `DISCORD_GUILD_ID`, `NEON_DATABASE_URL`
- Database: PostgreSQL (Neon) via Drizzle ORM

---

## 10. Alur Kerja Standar

### Saat user minta fitur baru:
1. Baca file yang relevan dulu (jangan asal edit)
2. Implementasi perubahan
3. Jalankan `git diff --check` untuk pastikan tidak ada konflik whitespace
4. Commit dengan pesan deskriptif
5. **Tanya user apakah ingin push**, atau langsung push jika user sudah bilang "push"

### Saat user bilang "push":
1. `git add <file-yang-berubah>`
2. `git commit -m "pesan"` (jika belum di-commit)
3. Push dengan Basic auth menggunakan token (lihat bagian 8)
4. Verifikasi hash remote sama dengan lokal
5. Laporkan hasil push dengan format ringkasan (lihat bagian 2)

### Saat user lapor bug:
1. Cari root cause dulu — baca file relevan, jangan langsung edit
2. Jelaskan root cause ke user sebelum fix (atau sekaligus dengan fix)
3. Terapkan fix minimal — jangan ubah hal yang tidak berkaitan
4. Commit + push jika diminta

---

## 11. Hal yang Tidak Boleh Dilakukan

- ❌ Jangan gunakan `luac` untuk validasi file di `games/` (tidak support Luau)
- ❌ Jangan `git push --force` kecuali user minta secara eksplisit
- ❌ Jangan hardcode URL, token, atau credential di kode
- ❌ Jangan tampilkan nilai actual dari secret/token
- ❌ Jangan ubah struktur file yang sudah ada tanpa alasan jelas
- ❌ Jangan buat toggle baru tanpa menambahkannya ke `SyncAllVisualUI`

---

*Prompt ini dibuat untuk konsistensi perilaku agen lintas sesi dan akun Replit.*
