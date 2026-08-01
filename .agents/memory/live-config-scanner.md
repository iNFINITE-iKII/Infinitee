---
name: Live config scanner
description: Safe runtime discovery of Res* configuration objects for Clover Origins
---

The live config scanner treats ReplicatedStorage config discovery as a read-only capability: it records every Res* object, reads all Res* ModuleScripts by default through protected calls, and reports unsupported types or require failures without stopping the game script. Metadata-only mode remains available with `ReadModules=false`.

**Why:** Res* entries can be ModuleScripts, Folders, or PackageLinks. Full discovery is useful for adapting to game updates, but blindly requiring arbitrary modules without `pcall` makes updates fragile and can trigger unintended module behavior.

**How to apply:** Keep scanner output separate from remote/action logic; use the registry for readers and UI, retain Workspace scanning as a fallback, and use `Scan({ReadModules=false})` when only object metadata is needed.