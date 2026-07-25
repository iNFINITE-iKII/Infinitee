---
name: IronSoul config and remote map
description: Peta 66 config IronSoul v1, batasan penggunaan, remote yang sudah terpetakan, dan urutan upgrade yang aman.
---

IronSoul v1 memiliki 66 dump konfigurasi di `games/config/`, bernomor 1–66 dan sinkron dengan `origin/main`. File-file ini adalah data dari `ReplicatedStorage.Configs`, bukan daftar `RemoteEvent` atau `RemoteFunction`. `64_RoundEnemy.txt`, `65_PackageLink.txt`, dan `66_World.txt` bertipe Folder/PackageLink, bukan ModuleScript biasa. Verifikasi kode menunjukkan script saat ini belum membaca seluruh 66 config secara live; sebagian besar masih menjadi referensi/dump analisis.

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

**Urutan upgrade yang disarankan:** (1) buat reader live yang aman dan hanya mengaktifkan config yang sudah divalidasi, (2) farm planner berbasis enemy/chest/egg/drop/world, (3) forge dan equipment optimizer, (4) quest/reward dashboard, (5) pet, expedition, bond, dan season pass satu per satu. Pertahankan struktur Luau yang ada dan validasi dengan tooling Luau-aware.

**Live Config Reader — penjelasan untuk agent berikutnya:** ini adalah fondasi yang membaca config langsung dari `ReplicatedStorage.Configs` saat runtime, lalu menyediakan data terpusat untuk Farm, Forge, Shop, UI, planner, dan dashboard. Tujuannya mengurangi dump lama dan hardcode, mengikuti enemy/loot/weapon/armor/shop/egg baru setelah update game, membuat dropdown UI dinamis, serta memudahkan validasi dan debugging. Reader tidak menjalankan remote, tidak mengubah inventory, tidak melakukan claim, fortify, enchant, hatch, atau action server lain.

Alur yang disarankan:
```text
ReplicatedStorage.Configs
  → ConfigReader.Load(name)
  → validasi tipe/field + cache
  → Farm/Forge/UI/Planner
  → gunakan remote hanya jika action-nya sudah terverifikasi
```

Reader harus memiliki timeout, menangani config yang belum muncul, membedakan ModuleScript dari Folder/PackageLink, memeriksa format yang berubah, dan mengembalikan kegagalan secara jelas. Mulai dari `ResEnemy`, `ResDropLoot`, `ResChestLoot`, `ResDragonEggLoot`, `ResOres`, `ResSeasonShop`, `ResWeapon`, dan `ResArmor`; jangan menganggap seluruh 66 config sudah terintegrasi hanya karena file dump-nya ada.

**Why:** dump config sudah jauh lebih lengkap daripada fitur yang saat ini dipakai script, dan verifikasi terbaru memastikan pembacaan live baru terbatas pada beberapa config. Memisahkan data reader dari remote mapping mencegah implementasi rapuh dan asumsi server yang salah.

**How to apply:** saat ada permintaan upgrade IronSoul v1, baca topik ini bersama `AGENT_PROMPT.md` dan `.agents/guides/ironsoul-read-map.md`; pilih hanya kategori/file yang relevan, lalu bedakan config live dari dump referensi. Laporkan root cause/alur dalam Bahasa Indonesia dan lakukan perubahan minimal.