## Why

The project needs a practical Azure Landing Zone foundation that follows Azure Well-Architected principles without incurring enterprise-scale network cost before real workloads exist. It must establish a hub-based platform network, low-cost operator access, shared services such as a central container registry, and private CI/CD execution for future workload VNets.

## What Changes

- Define a governance and cost-control baseline for the landing zone.
- Define a hub network foundation that is ready for future spoke VNets.
- Define low-cost operator connectivity using Point-to-Site VPN rather than higher-cost always-on management services.
- Define shared platform services hosted from the hub, including a central Azure Container Registry.
- Define GitHub self-hosted runner execution using Azure Container Apps Jobs with private access to landing-zone resources.
- Define workload spoke networking and the minimum connectivity model between spokes and the hub.

## Capabilities

### New Capabilities
- `landing-zone-governance`: Governance, observability, and cost-control requirements for the platform baseline.
- `hub-network-foundation`: Hub VNet, subnetting, address planning, and routing readiness for the landing zone core.
- `operator-connectivity`: Low-cost break-glass and operational access into the landing zone through VPN connectivity.
- `shared-platform-services`: Shared hub-hosted services such as the central container registry and related private connectivity.
- `runner-execution-platform`: GitHub Actions runner execution on Azure Container Apps Jobs with private network integration.
- `workload-spoke-networking`: Separate workload VNets peered to the hub with controlled connectivity boundaries.

### Modified Capabilities

## Impact

- Azure networking topology, address planning, and connectivity patterns
- Shared Azure platform services including Azure Container Registry
- GitHub Actions private runner hosting model
- Subscription governance, diagnostics, and cost controls
- Future workload onboarding model through spoke VNets
