# Agents

This repository currently defines **five custom agents** under `.github/agents/`. They are focused on designing, authoring, reviewing, and operating the Azure landing-zone deployment workflow.

## Shared context

All agents are expected to work from the current OpenSpec change:

- `openspec/changes/azure-landing-zone-foundation/proposal.md`
- `openspec/changes/azure-landing-zone-foundation/design.md`
- `openspec/changes/azure-landing-zone-foundation/specs/**/spec.md`

They should preserve the current architectural direction:

- **Bicep-first** infrastructure as code
- **hub-and-spoke** networking
- **low-cost defaults**
- **Point-to-Site VPN** for operator access
- **central ACR**
- **GitHub runners on Azure Container Apps Jobs**
- the **hub is a platform network**, not a general workload network

For Azure, Bicep, GitHub Actions, and Microsoft platform questions, agents should prefer the **Microsoft Learn MCP** when current official guidance is needed.

## Agent catalog

| Agent | File | Use it for | Main outputs |
| --- | --- | --- | --- |
| **Landing Zone Azure Platform Architect** | `.github/agents/landing-zone-azure-platform-architect.agent.md` | Platform architecture, deployment shape, scope boundaries, sequencing, Azure service selection | Module/resource graph, deployment model, scope strategy, assumptions and risks |
| **Landing Zone Bicep Planner** | `.github/agents/landing-zone-bicep-planner.agent.md` | Bicep decomposition, module contracts, outputs, dependency ordering, AVM-first planning | Module list, parameters, outputs, dependencies, deployment stages |
| **Landing Zone Workflow Author** | `.github/agents/landing-zone-workflow-author.agent.md` | Writing or refining `.github/workflows/deploy-landing-zone.yml` | Workflow YAML, inputs/outputs, environment and permissions model, verification notes |
| **Landing Zone Security Reviewer** | `.github/agents/landing-zone-security-reviewer.agent.md` | OIDC review, Azure RBAC scope review, supply-chain hardening, permission review | High-signal risk list, remediation steps, RBAC recommendations, workflow permission fixes |
| **Landing Zone Monitoring Operator** | `.github/agents/landing-zone-monitoring-operator.agent.md` | Deployment summaries, post-deploy checks, diagnostics hooks, operator handoff | Summary sections, health checks, diagnostic commands, triage notes |

## Recommended routing

Use the agents by concern:

1. **Start with architecture**
   - Use **Landing Zone Azure Platform Architect** when deciding the overall deployment shape.
2. **Move to IaC planning**
   - Use **Landing Zone Bicep Planner** when turning the design into modules and deployment stages.
3. **Write the workflow**
   - Use **Landing Zone Workflow Author** to create or refine the GitHub Actions pipeline.
4. **Review security before trusting it**
   - Use **Landing Zone Security Reviewer** to harden OIDC, RBAC, and action pinning.
5. **Add operational readiness**
   - Use **Landing Zone Monitoring Operator** to make deployments observable and supportable.

## Agent boundaries

### Landing Zone Azure Platform Architect

Use this agent when the main question is **"What should we deploy, at what scope, and in what order?"**

It is the best fit for:
- hub vs spoke decisions
- bootstrap concerns
- deciding where ACR, VPN, and runner infrastructure belong
- preserving low-cost defaults while keeping the design extensible

It should not be the primary agent for detailed YAML authoring or security-only review.

### Landing Zone Bicep Planner

Use this agent when the main question is **"How should the Bicep implementation be structured?"**

It is the best fit for:
- module boundaries
- parameters and outputs
- deployment dependencies
- AVM suitability
- cross-scope deployment planning

It should not be the primary agent for GitHub Actions authoring or post-deploy diagnostics.

### Landing Zone Workflow Author

Use this agent when the main question is **"How should the deployment workflow be implemented?"**

It is the best fit for:
- workflow stages such as validate, preview, deploy, and verify
- GitHub-hosted vs self-hosted bootstrap choices
- permissions and concurrency structure
- deployment summaries and artifact handling

It should not be treated as the final authority on least-privilege Azure access; hand that to the security reviewer.

### Landing Zone Security Reviewer

Use this agent when the main question is **"Is this deployment path safe enough?"**

It is the best fit for:
- OIDC federation design
- least-privilege Azure RBAC
- immutable SHA pinning for actions
- secret reduction
- identity separation between workflow, operators, and runtime resources

It should prioritize meaningful security findings over stylistic feedback.

### Landing Zone Monitoring Operator

Use this agent when the main question is **"How will operators understand and troubleshoot deployments?"**

It is the best fit for:
- `GITHUB_STEP_SUMMARY` content
- artifact capture for previews and outputs
- post-deploy health checks
- operator-facing Azure diagnostic commands
- triage guidance for ACR, networking, VPN, and ACA Jobs runner issues

It should keep observability practical and cost-aware.

## Supporting skills

The custom agents are designed to work with the repository skills under `.github/skills/`:

- `landing-zone-deployment-design`
- `workflow-oidc-hardening`
- `azure-rbac-minimization`
- `azure-deployment-guardrails`
- `landing-zone-cost-guardrails`
- `deployment-observability`

If the Azure plugin is installed, agents may also reuse upstream skills such as:

- `azure-validate`
- `azure-deploy`
- `azure-rbac`
- `azure-compliance`
- `azure-cost`
- `azure-diagnostics`
- `appinsights-instrumentation`

## Typical flow

```text
Landing Zone Azure Platform Architect
                ↓
      Landing Zone Bicep Planner
                ↓
      Landing Zone Workflow Author
                ↓
     Landing Zone Security Reviewer
                ↓
    Landing Zone Monitoring Operator
```

This is the default order for new work. For narrow tasks, invoke only the specialist that matches the problem.
