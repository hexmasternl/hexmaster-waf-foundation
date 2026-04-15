## Context

The current landing-zone foundation provisions hub networking, operator VPN access, a shared Key Vault, and an optional runner platform, but it does not define a shared log destination for foundational diagnostics. That leaves break-glass troubleshooting dependent on per-resource inspection and deployment artifacts instead of a small central workspace.

This change adds the smallest useful Azure Monitor footprint that still matches the repository direction: low-cost defaults, hub-hosted shared services, and practical operator diagnostics. The design must avoid turning the landing zone into a broad monitoring platform or introducing premium services such as Sentinel.

## Goals / Non-Goals

**Goals:**
- Add a shared Log Analytics workspace for foundational landing-zone diagnostics.
- Keep the baseline intentionally small with short retention and limited ingestion scope.
- Route diagnostics from selected foundational resources that are already central to operations.
- Expose enough outputs and documentation for deployment verification and break-glass workflows.

**Non-Goals:**
- Creating a full Azure Monitor governance baseline with alerts, action groups, or policy-driven remediation.
- Collecting diagnostics from every future workload resource or spoke by default.
- Adding Microsoft Sentinel, Application Insights, or long-retention analytics.
- Replacing deployment artifacts or existing Azure CLI verification steps.

## Decisions

### Add one shared workspace in the platform resource group

The landing zone will deploy a single Log Analytics workspace into the existing platform resource group alongside other shared platform services. This keeps foundational observability in the hub platform boundary instead of scattering monitoring state across connectivity and runner resource groups.

Alternatives considered:
- A separate monitoring resource group: cleaner separation, but extra structure without enough current scope.
- No shared workspace: cheapest option, but leaves diagnostics fragmented and weakens operations.

### Keep retention and daily ingestion defaults deliberately small

The workspace should default to a short retention window and a capped daily ingestion allowance sized for foundational resources rather than workloads. This preserves the low-cost design intent while still giving operators recent logs for deployment and break-glass investigations.

Alternatives considered:
- Long retention by default: improves history, but adds standing cost too early.
- No ingestion cap: simpler configuration, but weakens cost guardrails.

### Send diagnostics only from foundational resources with high operational value

The first baseline should target resources that are central to shared-platform operations: the shared Key Vault, Point-to-Site VPN gateway, runner autoscaler Function App and supporting storage, and the runner VM scale set when the pool is enabled. This captures the components most likely to matter during deployment failures, private access issues, and runner incidents.

Alternatives considered:
- Broad diagnostic coverage for every resource: more complete, but too expensive and noisy for the current stage.
- Key Vault only: minimal effort, but insufficient for VPN and runner troubleshooting.

### Keep observability configuration modular

The workspace and diagnostic settings should live in a dedicated platform-oriented module or submodule so the subscription entrypoint can enable the baseline without overloading the existing shared-services template. This keeps the design extensible for later additions such as alerts or policy assignments.

Alternatives considered:
- Embed all observability resources directly into `shared-services.bicep`: fewer files now, but mixes concerns and makes later growth harder.

## Risks / Trade-offs

- **Diagnostic category differences across resources** -> Keep the initial resource set explicit and map categories per resource type rather than assuming one pattern fits all.
- **Even minimal ingestion can drift upward** -> Use low retention and a daily cap, and limit the initial scope to foundational resources only.
- **Runner resources are optional** -> Make runner-related diagnostic settings conditional on the runner platform being deployed.
- **Operators may over-rely on logs that are not retained long** -> Keep deployment artifacts and CLI-based verification as complementary evidence, not replacements.

## Migration Plan

1. Add workspace configuration to the landing-zone parameter model with low-cost defaults.
2. Deploy the shared workspace in the platform resource group through a dedicated observability module.
3. Add diagnostic settings for the selected foundational resources, with conditional handling for optional runner resources.
4. Expose workspace identifiers and basic usage notes through deployment outputs and repository documentation.
5. Roll back by removing diagnostic settings first and then the workspace if the baseline proves too costly or noisy.

## Open Questions

- Which exact daily ingestion cap best fits the expected early-stage platform activity?
- Should the workspace use the PerGB2018 pricing model explicitly in parameters, or rely on Azure defaults unless an override is needed?
