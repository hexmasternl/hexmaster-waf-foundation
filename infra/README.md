# Infrastructure scaffold

This repository now uses a **Bicep-first** layout for the Azure landing zone foundation.

## Structure

- `landing-zone\main.bicep` - subscription-scope entry point for the landing zone foundation
- `landing-zone\main.bicepparam` - low-cost example parameters for a first deployment
- `modules\connectivity\hub-network.bicep` - hub VNet, subnetting, NSGs, route tables, and DNS baseline outputs
- `modules\connectivity\operator-connectivity.bicep` - Point-to-Site VPN gateway and operator access outputs
- `modules\platform\shared-services.bicep` - hub-hosted shared services including the central ACR, Key Vault, private endpoints, and private DNS
- `modules\platform\runner-execution.bicep` - Container Apps environment, runner identities, and optional GitHub runner job definition
- `modules\connectivity\workload-spoke.bicep` - standard workload spoke VNet, subnet isolation, and shared-service flow guardrails
- `landing-zone\workload-spokes.example.bicepparam` - example workload spoke onboarding parameters that align with the reserved spoke supernet
- `operations\break-glass-operating-model.yaml` - operator break-glass operating model and validation checks

## Current scope

This scaffold implements OpenSpec tasks:

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
  --parameters .\infra\landing-zone\main.bicepparam
```

## GitHub Actions workflow

The repository workflow `.github/workflows/deploy-landing-zone.yml` provides a staged deployment path:

1. **Validate** the Bicep source and parameter file
2. **Preview** infrastructure changes with subscription-scope what-if
3. **Deploy** the landing zone through GitHub OIDC-authenticated Azure access
4. **Verify** the deployment state and preserve operator-facing evidence

### Required repository configuration

Configure these repository or environment variables for the workflow:

- `AZURE_CLIENT_ID` - application or user-assigned managed identity client ID for the GitHub federated credential
- `AZURE_TENANT_ID` - Microsoft Entra tenant ID
- `AZURE_SUBSCRIPTION_ID` - target Azure subscription ID
- `AZURE_PRIMARY_LOCATION` - default deployment location for the subscription-scope deployment record, for example `westeurope`

Recommended GitHub environments:

- `landing-zone-dev`
- `landing-zone-test`
- `landing-zone-prod`

Use environment protection rules on the environments that should gate deployment.

### Azure setup requirements

The GitHub workflow uses **OIDC**, not a stored client secret, for the normal deployment path. The Azure deployment identity should:

- trust this repository through a GitHub federated credential
- have least-privilege rights to deploy the landing-zone subscription-scope Bicep entrypoint
- keep deployment access separate from runtime identities and operator break-glass access

At minimum, document and review whether the workflow requires:

- subscription-scope deployment rights
- resource group creation rights
- any role-assignment rights for the initial bootstrap path

### Usage

- **Pull requests** run validation and preview only
- **Pushes to `main`** run validation, preview, deployment, and verification
- **Manual dispatch** can run preview only or preview plus deployment by setting `execute_deploy`

Keep the `primary_location` workflow input aligned with the `primaryLocation` value inside the selected `.bicepparam` file.

### Failure triage

If a workflow run fails:

1. Review the `GITHUB_STEP_SUMMARY` sections for the failed stage
2. Download the uploaded validation, what-if, deployment, or verification artifacts
3. Re-run the equivalent Azure commands locally if needed:

```powershell
az deployment sub what-if `
  --name landing-zone-preview `
  --location westeurope `
  --parameters .\infra\landing-zone\main.bicepparam

az deployment sub show `
  --name <deployment-name> `
  --query properties.error
```

4. If the deployment succeeded but verification indicates a problem, inspect the deployment outputs and the operational artifacts under `infra\operations\`

## Connectivity notes

- The hub stays a **platform** network; workloads belong in separate spokes
- Operator access uses **Point-to-Site VPN** on **VpnGw1AZ** rather than Bastion
- Private DNS is centralized in the hub using Azure-provided DNS initially, with hub-linked private zones for future services
- Break-glass reachability to spokes depends on hub-spoke peering with **allowGatewayTransit** and **useRemoteGateways**
- The central ACR and shared Key Vault are deployed into the platform resource group and exposed over private endpoints in the hub
- Runner jobs use a dedicated Container Apps environment with separate identities for image pull and workload execution
- The default runner registration target is the GitHub organization `hexmasternl` in the `HexMaster Landingzone` runner group
- Workload spokes are allocated from the reserved **10.32.0.0/12** supernet and are expected to reserve space for workload, private-endpoint, and future expansion ranges
- Spoke NSGs allow only approved access to hub **shared-services** and **private-endpoints** prefixes and deny lateral traffic to the wider hub and other spokes

### Runner registration defaults

The landing-zone runner configuration now targets the GitHub organization runner endpoint by default:

```bash
./config.sh --url https://github.com/hexmasternl --runnergroup "HexMaster Landingzone" --token {{organizationsecret.RUNNER_DEPLOYMENT_TOKEN}}
./run.sh
```

Store the Container Apps scaler PAT in the Key Vault secret referenced by `runnerExecutionConfig.githubPatSecretUri`, and store the organization runner registration token in `runnerExecutionConfig.runnerDeploymentTokenSecretUri`.
