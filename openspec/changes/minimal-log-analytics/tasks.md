## 1. Parameterize the observability baseline

- [ ] 1.1 Add minimal Log Analytics configuration to `infra\landing-zone\main.bicep` with low-cost defaults for workspace retention and ingestion guardrails.
- [ ] 1.2 Extend landing-zone outputs so operators can discover the shared workspace name, resource ID, and any baseline observability notes after deployment.

## 2. Implement shared workspace resources

- [ ] 2.1 Create a dedicated platform observability module or submodule that deploys the shared Log Analytics workspace in the platform resource group.
- [ ] 2.2 Wire the new observability module into the subscription entrypoint without breaking the existing shared-services and runner deployment flow.

## 3. Attach foundational diagnostics

- [ ] 3.1 Add diagnostic settings for the shared Key Vault and Point-to-Site VPN gateway so their supported logs flow to the shared workspace.
- [ ] 3.2 Add conditional diagnostic settings for runner platform resources that are only deployed when the runner pool is enabled.

## 4. Document and verify operator usage

- [ ] 4.1 Update `infra\README.md` with the minimal observability scope, low-cost intent, and the foundational resources included in the baseline.
- [ ] 4.2 Extend deployment verification guidance so operators know how to locate and use the shared workspace during break-glass troubleshooting.
