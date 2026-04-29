# Infrastructure scaffold

This repository now uses a **Bicep-first** layout for the Azure landing zone foundation.

## Structure

- `landing-zone\main.bicep` - subscription-scope entry point for the landing zone foundation
- `landing-zone\main.bicepparam` - low-cost example parameters for a first deployment
- `modules\connectivity\hub-network.bicep` - hub VNet, subnetting, NSGs, route tables, and DNS baseline outputs
- `modules\connectivity\operator-connectivity.bicep` - Point-to-Site VPN gateway and operator access outputs
- `modules\platform\shared-services.bicep` - hub-hosted shared services including the existing central ACR connectivity, Key Vault, private endpoints, and private DNS
- `modules\platform\runner-execution.bicep` - VM scale set runner platform, execution identity, and webhook autoscaler Function App
- `modules\platform\observability.bicep` - shared Log Analytics workspace and foundational shared-service diagnostics baseline
- `modules\connectivity\workload-spoke.bicep` - standard workload spoke VNet, subnet isolation, and shared-service flow guardrails
- `landing-zone\workload-spokes.example.bicepparam` - example workload spoke onboarding parameters that align with the reserved spoke supernet
- `operations\break-glass-operating-model.yaml` - operator break-glass operating model and validation checks
- `operations\runner-bootstrap-runbook.yaml` - step-by-step runner bootstrap: PAT creation, webhook secret, runner group access, and org webhook setup

## Current scope

This scaffold implements OpenSpec tasks:

- **2.1** hub VNet address planning and dedicated subnets for VPN, shared services, private endpoints, and runner infrastructure
- **2.2** baseline NSG, route-table, and DNS patterns that keep the hub spoke-ready
- **3.1** Point-to-Site VPN gateway, OpenVPN tunnel path, and Microsoft Entra ID authentication metadata
- **3.2** break-glass operating model for reaching approved hub resources and peered spokes
- **4.1** central Azure Container Registry integration and shared image consumption
- **4.2** shared-service hosting pattern in a dedicated platform resource group with central private endpoint and DNS placement for future hub services
- **5.1** GitHub runner VM scale set boundary and webhook-driven autoscaling on the dedicated hub runner subnet
- **5.2** runner identities, ACR image pull model, Key Vault secret references, and private connectivity notes for hub-hosted services
- **6.1** workload spoke VNet pattern, peering model, and address-space onboarding constraints
- **6.2** workload-to-hub traffic guardrails for shared services access without enabling spoke-to-spoke transit
- minimal Log Analytics baseline for shared platform diagnostics with low-cost defaults and scoped foundational resource coverage

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
5. If the `observabilityBaseline.enabled` output is `true`, open the shared Log Analytics workspace identified in the deployment outputs and review recent platform diagnostics.

## Connectivity notes

- The hub stays a **platform** network; workloads belong in separate spokes
- Operator access uses **Point-to-Site VPN** on **VpnGw1AZ** rather than Bastion
- Private DNS is centralized in the hub using Azure-provided DNS initially, with hub-linked private zones for future services
- Minimal observability uses a shared Log Analytics workspace in the platform resource group with short retention and a small daily ingestion cap
- Break-glass reachability to spokes depends on hub-spoke peering with **allowGatewayTransit** and **useRemoteGateways**
- The shared Key Vault is deployed into the platform resource group, while the existing central ACR (`nvv54gsk4pteu`) in resource group `mvp-int-env` is consumed as an external dependency without landing-zone-managed network changes
- Runner compute uses a dedicated VM scale set resource group and hub subnet, with separate identities for workload execution and deployment automation
- The default runner registration target is the GitHub organization `hexmasternl` in the `HexMaster Landingzone` runner group
- Workload spokes are allocated from the reserved **10.32.0.0/12** supernet and are expected to reserve space for workload, private-endpoint, and future expansion ranges
- Spoke NSGs allow only approved access to hub **shared-services** and **private-endpoints** prefixes and deny lateral traffic to the wider hub and other spokes

### Runner registration defaults

The landing-zone runner uses an **Azure Virtual Machine Scale Set** plus a lightweight **Azure Function** webhook autoscaler. A single GitHub PAT stored in Key Vault handles both:

1. **Webhook-driven scaling** — the Function App reacts to `workflow_job` events and changes VMSS capacity between `1` and `10`
2. **Runner registration** — the VMSS cloud-init bootstrap calls the [registration token API](https://docs.github.com/en/rest/actions/self-hosted-runners#create-a-registration-token-for-an-organization) at runtime and runs `config.sh --ephemeral`

Runner registrations are **ephemeral** — each VM instance registers for a single job, executes it, deregisters, and then the systemd service is ready to register again while the VM remains in the scale set.

#### Secret requirements

The deployment workflow seeds both runner secrets into the platform Key Vault automatically when the corresponding GitHub Actions secrets are present:

| Key Vault secret | GitHub Actions secret | Purpose |
|---|---|---|
| `github-actions-pat` | `ADMIN_ORG_PAT` | PAT used by VM instances to obtain runner registration tokens at boot |
| `github-webhook-secret` | `RUNNER_WEBHOOK_SECRET` | Shared secret used by the autoscaler Function App to validate incoming `workflow_job` webhook payloads |

See `infra/operations/runner-bootstrap-runbook.yaml` for step-by-step instructions on creating these secrets.

#### VMSS bootstrap requirements

Before the runner pool can deploy and register successfully:

1. Replace the example `runnerExecutionConfig.adminPublicKey` value in `main.bicepparam` with a real SSH public key for break-glass access.
2. Create the `ADMIN_ORG_PAT` and `RUNNER_WEBHOOK_SECRET` secrets in the GitHub repository (or `landing-zone-dev` environment). The deployment will seed them into Key Vault automatically.
3. Create a runner group named **HexMaster Landingzone** in the GitHub organization under Settings → Actions → Runner groups and grant it access to this repository (and enable public repository access if the repo is public).
4. Configure a GitHub organization `workflow_job` webhook targeting the Function App URL returned in the `runnerExecutionPlatform.autoscaler.functionApp.webhookUrl` deployment output. Use the value of `RUNNER_WEBHOOK_SECRET` as the webhook shared secret.

#### Troubleshooting runner registration

If the VMSS instance is running but no runner appears in GitHub, check cloud-init logs:

```bash
az vmss run-command invoke \
  --resource-group <runner-rg> \
  --name <vmss-name> \
  --instance-id 0 \
  --command-id RunShellScript \
  --scripts "journalctl -u github-runner.service --no-pager -n 80"
```

Common causes:
- **Runner group not visible to the repo** — the most common issue for org runners. Go to Org → Settings → Actions → Runner groups → HexMaster Landingzone and verify the repository is listed under *Repository access*. If the repo is public, also enable *Allow public repositories*.
- **Key Vault secret missing** — both `github-actions-pat` and `github-webhook-secret` must exist before the first VM boots. Check that the deployment ran with `ADMIN_ORG_PAT` and `RUNNER_WEBHOOK_SECRET` set.
- **PAT scope insufficient** — the PAT needs `admin:org` (classic) or *Self-hosted runners: read and write* (fine-grained) to create registration tokens at the org level.
- **Runner group missing** — the group referenced in `runnerExecutionConfig.runnerGroup` must exist in the GitHub org before the VMSS instances boot.

The deployment workflow now also packages and zip-deploys the Function App code under `infra\runner-autoscaler\` after the infrastructure deployment succeeds.

## Observability baseline

The landing zone includes a **minimal** shared Log Analytics baseline for foundational platform diagnostics.

### Scope

- Shared Key Vault diagnostic logs and metrics
- Point-to-Site VPN gateway diagnostic logs
- Runner Function App logs and metrics when the runner pool is deployed
- Runner VM scale set metrics plus guest Linux syslog and detailed performance telemetry when the runner pool is deployed
- Runner autoscaler storage account metrics and service logs when the runner pool is deployed

### Low-cost intent

- The baseline is **not** a full monitoring platform
- Workspace retention defaults to **30 days**
- Daily ingestion is capped at **1 GB/day** by default
- Workload spokes are **not** onboarded automatically

### Operator workflow

1. Read the `observabilityBaseline` deployment output to find the workspace name, resource ID, and coverage notes.
2. Open the workspace **Logs** blade in the Azure portal.
3. Start with broad queries before drilling into resource-specific tables:

```kusto
AzureDiagnostics
| where TimeGenerated > ago(1h)
| take 50
```

```kusto
AzureMetrics
| where TimeGenerated > ago(1h)
| take 50
```

4. For runner guest telemetry, query the workspace tables populated by Azure Monitor Agent:

```kusto
Syslog
| where TimeGenerated > ago(1h)
| where ProcessName has 'runner' or SyslogMessage has 'github-runner'
| take 50
```

```kusto
InsightsMetrics
| where TimeGenerated > ago(1h)
| where Origin == 'vm.azm.ms'
| take 50
```

5. Use the workspace as recent operational evidence alongside the what-if, deployment, and verification artifacts from the workflow run.
