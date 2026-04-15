# Infrastructure scaffold

This repository now uses a **Bicep-first** layout for the Azure landing zone foundation.

## Structure

- `landing-zone\main.bicep` - subscription-scope entry point for the landing zone foundation
- `landing-zone\main.bicepparam` - low-cost example parameters for a first deployment
- `modules\connectivity\hub-network.bicep` - hub VNet, subnetting, NSGs, route tables, and DNS baseline outputs
- `modules\connectivity\operator-connectivity.bicep` - Point-to-Site VPN gateway and operator access outputs
- `modules\platform\shared-services.bicep` - hub-hosted shared services including the existing central ACR connectivity, Key Vault, private endpoints, and private DNS
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
- **4.1** central Azure Container Registry integration, private-link posture, and spoke consumption through hub-hosted private DNS
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
- The shared Key Vault is deployed into the platform resource group, and the existing central ACR (`nvv54gsk4pteu`) in resource group `mvp-int-env` is connected through a private endpoint in the hub
- Runner jobs use a dedicated Container Apps environment with separate identities for image pull and workload execution
- The default runner registration target is the GitHub organization `hexmasternl` in the `HexMaster Landingzone` runner group
- Workload spokes are allocated from the reserved **10.32.0.0/12** supernet and are expected to reserve space for workload, private-endpoint, and future expansion ranges
- Spoke NSGs allow only approved access to hub **shared-services** and **private-endpoints** prefixes and deny lateral traffic to the wider hub and other spokes

### Runner registration defaults

The landing-zone runner uses **Azure Container Apps Jobs** with the KEDA `github-runner` scaler. A single GitHub PAT stored in Key Vault handles both:

1. **KEDA scaling** — polls the GitHub API for queued workflow jobs
2. **Runner registration** — the container entrypoint calls the [registration token API](https://docs.github.com/en/rest/actions/self-hosted-runners#create-a-registration-token-for-an-organization) at runtime to get a short-lived token, then runs `config.sh --ephemeral`

Runners are **ephemeral** — they register, execute one workflow job, then deregister. They only appear in the GitHub UI while actively running a job.

#### PAT requirements

Create a classic PAT with the following scopes and store it as `github-actions-pat` in the platform Key Vault:

- `admin:org` — required to generate organization-level runner registration tokens
- `repo` — required for KEDA to detect queued jobs on private repositories

Then set `runnerExecutionConfig.githubPatSecretUri` to the Key Vault secret URI (e.g. `https://<vault-name>.vault.azure.net/secrets/github-actions-pat`).

#### Runner image bootstrap

Before the ACA Job can start, the runner container image must be pushed to the existing central ACR (`nvv54gsk4pteu`) in resource group `mvp-int-env`:

```bash
az acr build --registry <acr-name> --image github-actions-runner:latest ./infra/runner-image
```

> **Note:** The central ACR has public network access disabled. For the initial image build, either temporarily enable public access on the ACR or push via VPN/private endpoint connectivity.
