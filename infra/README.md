# Infrastructure scaffold

This repository now uses a **Bicep-first** layout for the Azure landing zone foundation.

## Structure

- `landing-zone\main.bicep` - subscription-scope entry point for the governance baseline
- `landing-zone\main.bicepparam` - low-cost example parameters for a first deployment
- `modules\governance\baseline.bicep` - naming, tagging, diagnostics, and cost baseline outputs
- `modules\governance\budget.bicep` - subscription budget resource
- `modules\connectivity\hub-network.bicep` - hub VNet, subnetting, NSGs, route tables, and DNS baseline outputs
- `modules\connectivity\operator-connectivity.bicep` - Point-to-Site VPN gateway and operator access outputs
- `modules\platform\shared-services.bicep` - hub-hosted shared services including the central ACR, Key Vault, private endpoints, and private DNS
- `modules\platform\runner-execution.bicep` - Container Apps environment, runner identities, and optional GitHub runner job definition
- `modules\connectivity\workload-spoke.bicep` - standard workload spoke VNet, subnet isolation, and shared-service flow guardrails
- `landing-zone\workload-spokes.example.bicepparam` - example workload spoke onboarding parameters that align with the reserved spoke supernet
- `operations\break-glass-operating-model.yaml` - operator break-glass operating model and validation checks

## Current scope

This scaffold implements OpenSpec tasks:

- **1.1** subscription baseline, naming conventions, required tags, diagnostics defaults, and budget creation
- **1.2** allowed service tiers and default cost-control posture for networking, registry, and runner hosting
- **2.1** hub VNet address planning and dedicated subnets for VPN, shared services, private endpoints, and Container Apps infrastructure
- **2.2** baseline NSG, route-table, and DNS patterns that keep the hub spoke-ready
- **3.1** Point-to-Site VPN gateway, OpenVPN tunnel path, and Microsoft Entra ID authentication metadata
- **3.2** break-glass operating model for reaching approved hub resources and peered spokes
- **4.1** central Azure Container Registry placement, Premium private-link posture, and spoke consumption through hub-hosted private DNS
- **4.2** shared-service hosting pattern in a dedicated platform resource group with central private endpoint and DNS placement for future hub services
- **5.1** Azure Container Apps managed environment boundary for GitHub runners on the dedicated hub runner subnet
- **5.2** runner identities, ACR image pull model, Key Vault secret references, and private connectivity notes for hub-hosted services
- **6.1** workload spoke VNet pattern, peering model, and address-space onboarding constraints
- **6.2** workload-to-hub traffic guardrails for shared services access without enabling spoke-to-spoke transit

## Deployment

```powershell
az deployment sub create `
  --location westeurope `
  --template-file .\infra\landing-zone\main.bicep `
  --parameters .\infra\landing-zone\main.bicepparam
```

## Cost guardrails encoded in the baseline

- **Network** defaults to hub-and-spoke peering with **Point-to-Site VPN** and no Azure Firewall, Virtual WAN, NAT Gateway, or Bastion by default
- **Registry** defaults to **Premium SKU** Azure Container Registry because private endpoints are part of the baseline connectivity posture
- **Runners** default to **Azure Container Apps Jobs on Consumption**
- Higher-cost services require an explicit architecture review before adoption
- Diagnostics default to Log Analytics only when a workspace is supplied, preventing accidental standing-cost services during bootstrap

## Connectivity notes

- The hub stays a **platform** network; workloads belong in separate spokes
- Operator access uses **Point-to-Site VPN** on **VpnGw1** rather than Bastion
- Private DNS is centralized in the hub using Azure-provided DNS initially, with hub-linked private zones for future services
- Break-glass reachability to spokes depends on hub-spoke peering with **allowGatewayTransit** and **useRemoteGateways**
- The central ACR and shared Key Vault are deployed into the platform resource group and exposed over private endpoints in the hub
- Runner jobs use a dedicated Container Apps environment with separate identities for image pull and workload execution
- Workload spokes are allocated from the reserved **10.32.0.0/12** supernet and are expected to reserve space for workload, private-endpoint, and future expansion ranges
- Spoke NSGs allow only approved access to hub **shared-services** and **private-endpoints** prefixes and deny lateral traffic to the wider hub and other spokes
