---
name: Luau validation
description: Environment-specific validation constraints for Roblox Luau scripts
---

Standard `luac` is not a reliable parser for Roblox Luau files because the project uses Luau-only syntax such as `continue` and conditional expressions. A `luac` failure does not by itself indicate a regression.

**Why:** The imported game scripts contain valid Roblox Luau constructs that standard Lua rejects.

**How to apply:** Prefer a Luau-aware parser when available. Otherwise use diff checks, reference searches, and focused static block checks while explicitly reporting that full parser validation was unavailable.