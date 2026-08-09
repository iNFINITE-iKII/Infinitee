# IronSoul v1 — Read Map

Gunakan file ini sebagai peta baca terarah. Jangan membaca seluruh daftar pada setiap permintaan.

## Urutan konteks minimum

Untuk `AUDIT`, `BUG_FIX`, atau `FEATURE`:

1. `AGENT_PROMPT.md`
2. `.agents/memory/MEMORY.md`
3. `.agents/memory/ironsoul-config-map.md`
4. `games/ironsoulv1.lua`
5. `games/ironsoulv1/loader.lua`
6. `games/ironsoulv1/core.lua`
7. File kategori terkait di tabel berikut

Untuk `UI`, mulai dari file UI terkait dan baca `core.lua` hanya jika membutuhkan `EngineConfig`/`Hub`.

## Pemetaan kategori

| Kategori | File utama | Config awal |
|---|---|---|
| Farm enemy/chest/egg/loot | `farm.lua`, `combat.lua`, `navigation.lua`, `ui/tab_farm.lua` | `ResEnemy`, `ResDropLoot`, `ResChestLoot`, `ResDragonEggLoot`, `RoundEnemy`, `World` |
| Forge/QTE/ore | `auto_forge.lua`, `ui/tab_forge.lua`, `ui/tab_sell.lua` | `ResOres`, `ResForgeQTE`, `ResWeapon`, `ResArmor`, `ResFortifyConfig`, `ResFortifyCost` |
| Enchant/unforge/fortify/scroll | `auto_forge.lua`, `ui/tab_forge.lua`, `ui/tab_sell.lua`, `core.lua` | `ResEnchantedStoneConfig`, `ResUnForge`, `ResFortifyConfig`, `ResFortifyCost`, `ResScrolls` |
| Weapon/armor/equipment | `ui/tab_sell.lua`, `farm.lua`, `auto_forge.lua`, `core.lua` | `ResWeapon`, `ResArmor`, `ResWeaponProbability`, `ResArmorProbability` |
| Potion/buff | `auto_potion.lua`, `buff_card.lua`, `ui/tab_autopotion.lua`, `ui/tab_farm.lua` | `ResPotion`, `ResBuff`, `ResTimedBuff` |
| Shop/buy/sell | `farm.lua`, `ui/tab_autobuy.lua`, `ui/tab_sell.lua`, `core.lua` | `ResShop_Gold`, `ResShop_Bond`, `ResSeasonShop`, `ResHonorStore`, `ResProducts`, `ResGamePass` |
| Quest/achievement/reward | `ui/tab_util.lua`, `ui/tab_npc.lua`, `combat.lua` | `ResAchievement`, `ResDailyQuest`, `ResDailyQuestReward`, `ResDailyTask`, `ResEventTask`, `ResMainTask`, `ResDailyReward`, `ResGuidebookReward` |
| Season/update pass | `farm.lua`, `ui/tab_util.lua`, `core.lua` | `ResSeasonPassTask`, `ResSeasonPassLevel`, `ResSeasonPass`, `ResUpdateLog` |
| Pet/expedition/bond | `ui/tab_npc.lua`, `ui/tab_autobuy.lua`, `core.lua` | `ResPets`, `ResPetsEgg`, `ResPetsSkill`, `ResPetsExpeditionSlot`, `ResBondLevel`, `ResBondTask` |
| Race/attribute/skill | `ui/tab_util.lua`, `ui/tab_farm.lua`, `core.lua` | `ResRace`, `ResAttributeUpgrade`, `ResSkillTree`, `ResSkillStage`, `ResSkill`, `ResProbabilityUp` |
| UI/profile/translation | `ui/ui_core.lua`, `ui_sync.lua`, `config_system.lua`, `translate.lua` | Tidak wajib; cek `EngineConfig` dan `VisualConfig` |

## Cara memverifikasi config

Bedakan tiga kondisi berikut:

- `DATA_DUMP`: hanya ada file `games/config/*.txt`.
- `LIVE_CONFIG`: kode melakukan `require` atau membaca object dari `ReplicatedStorage.Configs` saat runtime.
- `PLANNER_ONLY`: data hanya dipakai untuk scanner, filter, kalkulator, dashboard, atau rekomendasi.

Jika membuat `ConfigReader`, wajib gunakan timeout, validasi tipe/field, cache, dan error yang jelas. Jangan memproses semua object dengan `require`: `RoundEnemy` dan `World` adalah Folder, sedangkan `PackageLink` bukan ModuleScript biasa.

Config awal untuk reader:

```text
ResEnemy
ResDropLoot
ResChestLoot
ResDragonEggLoot
ResOres
ResSeasonShop
ResWeapon
ResArmor
```

## Cara memverifikasi remote

Remote utama yang diekspor dari `core.lua`:

```text
PlayerActionRE
GameRoundRE
EquipmentRE
ForgeRF
MaterialRE
WorldPlaceRE
WorldBonusCardRE
GameMatchRE
SeasonUtilRE
```

Remote dinamis yang perlu dicari di file kategori:

```text
CodeRE
RaceRE
TaskRE
UpdateLogSystem.RemoteEvent
ConsumableShopUtil.RemoteEvent
WindowUtil.RemoteEvent
```

Gunakan status `CONFIRMED_REMOTE` hanya jika remote dan action benar-benar terlihat dipanggil oleh kode. Jika remote, argument, atau respons server belum terbukti, gunakan `UNVERIFIED` dan jangan menebak.

## Batas pembacaan dan perubahan

- Audit: baca dan laporkan saja; jangan mengubah kode.
- Bug fix: temukan root cause dan dependency terkait sebelum mengedit.
- Fitur: baca modul kategori, config yang relevan, dan remote yang sudah dipakai.
- UI: jangan memetakan remote jika perubahan hanya visual.
- Config: jangan menganggap dump sebagai config live.
- Remote belum terverifikasi: mulai dari planner/read-only.
- Setelah alur utama jelas, berhenti membaca file tambahan yang tidak memengaruhi keputusan.

## Format laporan audit

```text
Status data: DATA_DUMP / LIVE_CONFIG
Status remote: CONFIRMED_REMOTE / UNVERIFIED
Kategori: [kategori permintaan]
File yang dibaca: [daftar singkat]
Alur saat ini: [input → logic → remote/UI → output]
Gap: [bagian yang belum ada atau belum terverifikasi]
Rencana aman: [perubahan minimal atau planner-only]
```