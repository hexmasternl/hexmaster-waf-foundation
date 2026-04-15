## Why

The landing zone foundation already defines networking, private access, and runner execution, but it does not yet define a minimal central logging baseline. Adding a small Log Analytics footprint now makes break-glass diagnostics and deployment triage practical without pushing the design toward an enterprise-cost monitoring stack.

## What Changes

- Add a minimal hub-aligned Log Analytics baseline for foundational landing-zone resources.
- Define which platform resources must send diagnostics to the shared workspace first, with low-cost defaults and short retention.
- Define operator-facing expectations for using the workspace during deployment verification and break-glass investigation.
- Keep the scope intentionally small by avoiding broad data collection, Microsoft Sentinel, or expansive monitoring packages.

## Capabilities

### New Capabilities
- `landing-zone-observability`: Minimal central logging requirements for foundational landing-zone resources, workspace retention, and operator diagnostics workflows.

### Modified Capabilities

## Impact

- `infra\landing-zone\main.bicep` parameter shape and outputs
- A new or extended platform module under `infra\modules\platform\`
- Diagnostic settings for selected foundational resources such as Key Vault, VPN gateway, Function App, VMSS, and deployment-related platform components
- `infra\README.md` and operational guidance for verification and troubleshooting
