---
name: Live config scanner
description: Safe runtime discovery of Res* configuration objects for Clover Origins
---

The live config scanner treats `ReplicatedStorage.Configs` discovery as a read-only capability: it records every descendant, reads all ModuleScripts by default through protected calls, prints the scan to console, and reports unsupported types or require failures without stopping the game script. Metadata-only mode remains available with `ReadModules=false`.

**Why:** Configs can contain ModuleScripts, Folders, or PackageLinks. Full discovery is useful for adapting to game updates, but blindly requiring arbitrary modules without `pcall` makes updates fragile and can trigger unintended module behavior.

**How to apply:** Keep scanner output separate from remote/action logic; use the registry for readers and UI, retain Workspace scanning as a fallback, and use `Scan({ReadModules=false})` when only object metadata is needed. Use `MaxDepth` and `MaxEntries` to keep console output manageable. Keep `Mobs.SuperBosses` as a separate catalog and exclude its runtime models from the regular mob list.