---
name: landing-zone-cost-guardrails
description: Keep the landing zone workflow and infrastructure defaults aligned with the project's cost-first goals.
license: MIT
metadata:
  author: Copilot
  version: "1.0.0"
---

# Landing Zone Cost Guardrails

Use this skill when the workflow or Bicep design could accidentally introduce expensive defaults.

## Cost posture

The landing zone is intended to be Well-Architected and extremely cost effective. Cost-heavy services must be deliberate exceptions, not silent defaults.

## Guardrails

- Avoid Azure Virtual WAN by default.
- Avoid Azure Bastion by default.
- Avoid Azure Firewall by default.
- Avoid NAT Gateway unless there is a proven need.
- Prefer ACA Jobs or other scale-to-zero patterns where they fit.
- Keep monitoring retention and premium SKUs intentional.
- Prefer a single hub with later growth paths over premature platform sprawl.

## Workflow checks

1. Call out any feature that materially changes the expected monthly cost.
2. Require explicit flags or parameters for premium services.
3. Keep low-cost defaults documented in the workflow and module parameters.
4. Surface cost-sensitive changes in the workflow summary.

## Reuse

If Azure plugin skills are installed, pair this skill with:
- `azure-cost`
- `azure-compliance`
