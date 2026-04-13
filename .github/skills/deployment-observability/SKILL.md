---
name: deployment-observability
description: Add deployment summaries, verification steps, diagnostics references, and operator-facing observability to the landing zone workflow.
license: MIT
metadata:
  author: Copilot
  version: "1.0.0"
---

# Deployment Observability

Use this skill when adding verification and troubleshooting support to the landing zone deployment workflow.

## Objectives

- Make every deployment easy to inspect after the fact.
- Capture the resource outputs operators need during incidents.
- Provide clear post-deploy checks for the platform resources most likely to fail.

## Include in the workflow

- `GITHUB_STEP_SUMMARY` output for key resources and next actions
- artifact capture for preview output and deployment outputs
- post-deploy checks for:
  - hub VNet and spoke connectivity
  - VPN gateway presence
  - ACR readiness
  - ACA Jobs runner resources
  - private endpoint and DNS dependencies if present

## Operator handoff

Provide:
- resource names and IDs
- resource groups
- key outputs and login server names
- follow-up CLI commands for health checks
- a short triage section for common failure paths

## Reuse

If Azure plugin skills are installed, pair this skill with:
- `azure-diagnostics`
- `appinsights-instrumentation`

Expected output:
- workflow summary sections
- verification steps
- diagnostic commands and likely failure points
