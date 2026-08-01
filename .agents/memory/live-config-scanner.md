---
name: Live config scanner
description: Safe runtime discovery of Res* configuration objects for Clover Origins
---

The live config scanner treats ReplicatedStorage config discovery as a read-only capability: it records every Res* object, only reads verified ModuleScript names through a whitelist, and reports unsupported types or require failures without stopping the game script.

**Why:** Res* entries can be ModuleScripts, Folders, or PackageLinks, and blindly requiring or treating all of them as data makes updates fragile and can trigger unintended module behavior.

**How to apply:** Keep scanner output separate from remote/action logic; use the registry for readers and UI, retain Workspace scanning as a fallback, and expand the whitelist only after each config shape is verified.