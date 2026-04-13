## 1. Governance and cost baseline

- [x] 1.1 Define the subscription, naming, tagging, diagnostics, and budget baseline for the landing zone.
- [x] 1.2 Define the allowed service tiers and default cost-control posture for network, registry, and runner components.

## 2. Hub network foundation

- [x] 2.1 Define the hub VNet address plan and required subnets for VPN, shared services, private endpoints, and Container Apps infrastructure.
- [x] 2.2 Define the baseline NSG, route-table, and DNS patterns that preserve future spoke onboarding and later routing upgrades.

## 3. Operator connectivity

- [x] 3.1 Define the Point-to-Site VPN access path, authentication model, and operator reachability requirements.
- [x] 3.2 Define the break-glass operating model for accessing hub and spoke resources during failures.

## 4. Shared platform services

- [x] 4.1 Define the central Azure Container Registry placement, private connectivity model, and spoke consumption pattern.
- [x] 4.2 Define the shared-service hosting pattern in the hub for future platform services that must be consumed by multiple spokes.

## 5. Runner execution platform

- [x] 5.1 Define the Azure Container Apps environment and job execution boundaries for GitHub self-hosted runners.
- [x] 5.2 Define runner identity, image retrieval, secret handling, and private connectivity to hub-hosted services and Azure resources.

## 6. Workload spoke networking

- [x] 6.1 Define the standard spoke VNet pattern, peering model, and address-space constraints for workload onboarding.
- [x] 6.2 Define the allowed traffic flows between spokes and the hub, including access to shared services without collapsing isolation boundaries.
