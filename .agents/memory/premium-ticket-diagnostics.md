---
name: Premium ticket diagnostics
description: Durable debugging rule for the Discord premium ticket flow
---

The premium ticket flow must preserve the failing stage when reporting errors; a generic interaction fallback alone cannot distinguish Neon/database failures from Discord permission or channel-creation failures.

**Why:** Production users only saw the same internal-error response for multiple unrelated failure points, which made Railway debugging impossible without stage-aware logs.

**How to apply:** Keep stage labels around database lookups/inserts, role validation, category/channel creation, and ticket-message sending; use Railway logs to identify the exact failing operation after redeploy.