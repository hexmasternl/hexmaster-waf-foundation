---
name: landing-zone-deployment-design
description: Turn the Azure landing zone specs into a Bicep-first deployment model, module graph, and GitHub Actions staging plan.
license: MIT
metadata:
  author: Copilot
  version: "1.0.0"
---

# Landing Zone Deployment Design

Use this skill when designing the Bicep structure or the deployment stages for the landing zone.

## Goals

- Translate the OpenSpec landing-zone artifacts into implementation-ready deployment boundaries.
- Make bootstrap constraints explicit.
- Produce a design that a GitHub Actions workflow can execute deterministically.

## Inputs to read first

- `openspec/changes/azure-landing-zone-foundation/proposal.md`
- `openspec/changes/azure-landing-zone-foundation/design.md`
- `openspec/changes/azure-landing-zone-foundation/specs/**/spec.md`

## Workflow

1. Identify required deployment scopes such as subscription, resource group, hub, and spoke.
2. Derive the deployment sequence from the capability order already defined in OpenSpec.
3. Split the design into modules or deployment units with clean inputs and outputs.
4. Highlight bootstrap constraints, especially where the runner platform depends on resources that the workflow itself must deploy first.
5. Identify which outputs the workflow needs for later steps, summaries, and verification.

## Required design checks

- Keep the hub as a platform boundary.
- Keep workloads in spokes.
- Preserve low-cost defaults.
- Keep expensive services behind explicit feature flags.
- Leave space for future routing and security upgrades.

## Deliverables

- module graph
- deployment stage order
- parameter and output contract
- bootstrap notes
- assumptions and trade-offs
