---
name: IronSoul config and remote map
description: Peta 66 config IronSoul v1, batasan penggunaan, remote yang sudah terpetakan, dan urutan upgrade yang aman.
---

IronSoul v1 memiliki 66 dump konfigurasi di `games/config/`, bernomor 1–66 dan sinkron dengan `origin/main`. File-file ini adalah data dari `ReplicatedStorage.Configs`, bukan daftar `RemoteEvent` atau `RemoteFunction`. `64_RoundEnemy.txt`, `65_PackageLink.txt`, dan `66_World.txt` bertipe Folder/PackageLink, bukan ModuleScript biasa.

**Remote yang sudah terpetakan:**
- `PlayerActionRE` — serangan dasar dan skill; `ReplicatedStorage.Remotes.PlayerActionRE`.
- `GameRoundRE` — replay; `ReplicatedStorage.Remotes.GameRoundRE`.
- `EquipmentRE` — ganti slot weapon dan jual equipment.
- `ForgeRF` — forge/QTE/hasil forge dan jual ore.
- `MaterialRE` — jual material.
- `WorldPlaceRE` — pilih world dan kembali lobby.
- `WorldBonusCardRE` — pilih/unlock buff card.
- `GameMatchRE` — buat/tinggalkan room dan friend-only.
- `SeasonUtilRE` — pembelian Season Shop.

Remote yang dicari secara dinamis mencakup `CodeRE`, `RaceRE`, `UpdateLogSystem.RemoteEvent`, `ConsumableShopUtil.RemoteEvent`, `TaskRE`, dan `WindowUtil.RemoteEvent`. Sebagian action selain yang sudah dipakai di kode belum terverifikasi.

**Batasan penting:** jangan menebak remote atau argument server dari nama config. Untuk fitur seperti fortify, enchant, unforge, attribute upgrade, skill unlock, pet hatch/equip/expedition, bond, achievement claim, daily reward, dan season-pass claim, petakan alur resmi/berwenang terlebih dahulu. Config dapat dipakai langsung untuk reader, planner, scanner, filter, dan dashboard tanpa menambah remote.

**Urutan upgrade yang disarankan:** (1) reader 66 config secara live dari `ReplicatedStorage.Configs`, (2) farm planner berbasis enemy/chest/egg/drop/world, (3) forge dan equipment optimizer, (4) quest/reward dashboard, (5) pet, expedition, bond, dan season pass satu per satu. Pertahankan struktur Luau yang ada dan validasi dengan tooling Luau-aware.

**Why:** dump config sudah jauh lebih lengkap daripada fitur yang saat ini dipakai script, tetapi data statis tidak menjamin adanya remote/action yang kompatibel. Memisahkan data reader dari remote mapping mencegah implementasi rapuh dan asumsi server yang salah.

**How to apply:** saat ada permintaan upgrade IronSoul v1, baca topik ini bersama `AGENT_PROMPT.md`, cek kode terbaru di `games/ironsoulv1/`, lalu gunakan config live bila memungkinkan. Laporkan root cause/alur dalam Bahasa Indonesia dan lakukan perubahan minimal.