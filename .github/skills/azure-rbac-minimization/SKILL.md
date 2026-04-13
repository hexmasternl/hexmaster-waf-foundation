---
name: azure-rbac-minimization
description: Select the smallest Azure roles and scopes that let the landing zone workflow deploy infrastructure without granting unnecessary power.
license: MIT
metadata:
  author: Copilot
  version: "1.0.0"
---

# Azure RBAC Minimization

Use this skill when choosing Azure roles for the GitHub federated identity, deployment principals, or runtime identities created by the landing zone.

## Principles

- Prefer built-in roles before custom roles.
- Prefer the smallest scope that works.
- Separate bootstrap deployment access from runtime service access.
- Do not reuse operator credentials for automation.

## Workflow

1. List the actual deployment actions the workflow must perform.
2. Determine whether those actions are subscription-scoped, resource-group-scoped, or resource-specific.
3. Pick the smallest built-in role that satisfies the deployment path.
4. Only propose a custom role if no built-in role safely fits.
5. Document the reason for the chosen scope and role.

## Questions to answer

- Does the workflow need to create resource groups or only deploy into existing ones?
- Does it need role assignment rights, or should role assignments be staged separately?
- Are there identities for ACA Jobs runners that need narrower runtime roles than the workflow identity?

## Reuse

If Azure plugin skills are installed, use:
- `azure-rbac`

Expected output:
- recommended role names
- recommended scopes
- rationale and exceptions
