---
name: UI input compatibility
description: CreateInputUI supports both explicit numeric and legacy callback argument forms
---

`CreateInputUI` must accept both `(parent, label, default, numeric, callback, langKey)` and the older `(parent, label, default, callback, langKey)` form.

**Why:** Some game tabs omit the explicit numeric flag, which shifts the callback into the numeric parameter and silently prevents settings such as Burst multiplier from being saved.

**How to apply:** Keep the normalization at the shared UI boundary, then let each callback perform its own `tonumber` and clamping.