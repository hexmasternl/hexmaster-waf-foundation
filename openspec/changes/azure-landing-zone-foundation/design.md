## Context

The landing zone is intended to host shared platform services first and workload environments later. The current priority is to establish an Azure foundation that is aligned with Azure Well-Architected guidance while remaining extremely cost effective. The design must include a VNet-based foundation, support future workload routing through separate spokes, provide a central Azure Container Registry, host GitHub Actions runners in Azure Container Apps Jobs, and offer a simple operator access path during failures.

The design assumes an early-stage platform with limited initial workload count. It therefore favors a minimal hub-and-spoke model over an enterprise-heavy topology with Azure Virtual WAN, centralized firewalls, or always-on jump-host infrastructure.

## Goals / Non-Goals

**Goals:**
- Establish a hub-and-spoke landing-zone topology that can grow without reworking core network boundaries.
- Keep the initial platform cost low by avoiding premium network services unless they are required.
- Isolate platform concerns from future application workloads.
- Provide private execution for GitHub Actions jobs that need access to Azure resources inside the landing zone.
- Provide low-cost operator access for investigation and break-glass scenarios.
- Define governance and cost guardrails that keep the platform intentionally lean.

**Non-Goals:**
- Defining workload-specific application architectures.
- Introducing Azure Virtual WAN, centralized firewall inspection, or global transit from day one.
- Defining a multi-region disaster recovery strategy.
- Defining every shared service that may later be hosted in the hub.

## Decisions

### Use a minimal hub-and-spoke topology

The landing zone uses one hub VNet for platform services and separate spoke VNets for workloads. This creates clean trust boundaries while keeping the initial network model simple and inexpensive.

Alternatives considered:
- Single flat VNet for all services and workloads: cheaper to start, but mixes trust zones and creates rework when workloads need isolation.
- Azure Virtual WAN: stronger managed transit capabilities, but unnecessary cost and abstraction for the current scope.

### Treat the hub as a platform network

The hub hosts operator connectivity, shared services, and the runner execution platform. Workload resources belong in spokes rather than in the hub. This preserves the hub as a shared platform boundary and limits the blast radius of CI/CD execution.

Alternatives considered:
- Hosting early workloads in the hub: simpler at first, but erodes isolation between runners, operators, and applications.

### Use Point-to-Site VPN for operator access

The primary operator access path is Point-to-Site VPN into the hub. This provides low-cost break-glass access without requiring Azure Bastion, jump-box VMs, or more complex remote access platforms.

Alternatives considered:
- Azure Bastion: easier browser-based access but higher standing cost.
- CI/CD-only administration: lower exposure, but insufficient for break-glass troubleshooting.

### Host GitHub runners on Azure Container Apps Jobs

GitHub self-hosted runners are implemented with Azure Container Apps Jobs integrated into the landing-zone network. This supports ephemeral job execution and low idle cost while keeping network access private.

Alternatives considered:
- VM or VMSS-based runners: broader compatibility, but higher steady-state cost and more patching overhead.
- AKS-based runners: flexible, but operationally heavy for the current stage.

### Use central shared services in the hub

The hub hosts shared platform services, including a central Azure Container Registry, and exposes them to spokes through private networking patterns. Shared services are private by default where practical.

Alternatives considered:
- Per-spoke registries and duplicated services: simpler isolation, but duplicates cost and management effort.

### Leave room for later routing controls

The initial topology uses peering and subnet segmentation. Address space, route-table boundaries, and subnet placement must permit later addition of centralized egress, inspection, or separate runner VNets without renumbering the platform.

Alternatives considered:
- Implementing centralized egress and inspection immediately: stronger control posture, but misaligned with the current cost target.

## Risks / Trade-offs

- **Container Apps Jobs runner compatibility gaps** -> Restrict the initial runner scope to workflows that do not require VM-only features or privileged Docker semantics.
- **Hub concentration risk** -> Keep workloads out of the hub and isolate runners in dedicated subnets and identities.
- **Future security upgrades may require network changes** -> Reserve address space and routing boundaries now so stronger controls can be added without redesigning the topology.
- **P2S VPN is less polished than Bastion for some operators** -> Keep the access path simple, documented, and limited to operational scenarios where direct network reachability is required.
