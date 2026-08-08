---
name: Railway npm registry
description: Npm lockfiles generated inside Replit can contain internal package-firewall URLs that external Railway builds cannot reach.
---

Keep npm lockfiles used by Railway pointed at `https://registry.npmjs.org`, and verify a clean install/build outside the Replit package firewall before pushing. The build can pass locally while Railway fails at image creation if the lockfile retains internal `replit.local` tarball URLs.

**Why:** Replit's package firewall rewrites resolved tarball URLs for local installs; those URLs are not available to Railway.

**How to apply:** After dependency changes, inspect lockfiles for `replit.local`, regenerate with the public npm registry, and run the same Railway build command from a clean dependency directory.