---
name: GitHub PAT push
description: Authentication behavior for pushing to the imported GitHub repository
---

For Git HTTPS pushes with the repository PAT, GitHub accepted an `Authorization: Basic` header built from `x-access-token:<PAT>`. A Bearer header was valid for the GitHub API but rejected by the Git smart-HTTP endpoint.

**Why:** The PAT was valid and had repository scope, but the first Git push attempts failed because the wrong authorization scheme was used.

**How to apply:** Keep the token in the secret store and use Basic authentication only for the Git command; never print or persist the token.