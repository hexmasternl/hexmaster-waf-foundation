---
name: azure-deployment-guardrails
description: Add validation, preview, and fail-fast guardrails to the landing zone deployment workflow before any Azure changes are applied.
license: MIT
metadata:
  author: Copilot
  version: "1.0.0"
---

# Azure Deployment Guardrails

Use this skill when writing the validation and preview parts of the landing zone workflow.

## Objectives

- Fail early on invalid Bicep, missing parameters, or obvious scope mistakes.
- Surface Azure changes through preview output before deployment.
- Keep deployment jobs deterministic and reviewable.

## Recommended stages

1. Syntax and structure validation
2. Static checks on naming, parameters, and required files
3. Bicep build or lint
4. What-if or preview execution
5. Deploy only after preview succeeds
6. Post-deploy verification

## Guardrails to enforce

- Do not deploy if validation or preview fails.
- Keep preview output as an artifact or summary.
- Use path filters where they reduce unnecessary infra runs.
- Make manual dispatch inputs explicit for higher-risk changes.
- Treat bootstrap constraints as first-class: the workflow must still work before the ACA Jobs runner platform exists.

## Reuse

If Azure plugin skills are installed, pair this skill with:
- `azure-validate`
- `azure-deploy`

Expected output:
- validation job design
- preview job design
- deploy gate conditions
- operator-facing failure messages
