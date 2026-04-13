---
name: workflow-oidc-hardening
description: Harden GitHub Actions workflows for Azure deployment with OIDC, least privilege permissions, immutable action pinning, and environment protection.
license: MIT
metadata:
  author: Copilot
  version: "1.0.0"
---

# Workflow OIDC Hardening

Use this skill when authoring or reviewing a GitHub Actions workflow that deploys Azure resources.

## Security baseline

- Prefer GitHub OIDC and Azure workload identity federation over static secrets.
- Pin all actions to full commit SHAs with version comments.
- Set workflow permissions to the minimum possible and widen them only at the job level.
- Use environment approvals for higher-risk deployment targets.
- Use concurrency groups to prevent overlapping infrastructure changes.

## Workflow guidance

1. Identify which jobs truly need Azure access.
2. Grant `id-token: write` only to those jobs.
3. Limit `contents`, `pull-requests`, and `actions` permissions to the minimum needed.
4. Keep build, preview, deploy, and verify as separate concerns.
5. Keep bootstrap deployment paths distinct from steady-state self-hosted runner assumptions.

## OIDC review checklist

- Is the federated credential bound to the right repository, branch, tag, or environment?
- Is there a smaller Azure RBAC scope than the current proposal?
- Are any static Azure credentials still present?
- Are environment protections aligned with the deployment risk?
- Are action references immutable?

## Reuse

If Azure plugin skills are installed, pair this skill with:
- `azure-rbac`
- `azure-compliance`
