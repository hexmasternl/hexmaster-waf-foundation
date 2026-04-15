## ADDED Requirements

### Requirement: The landing zone SHALL provide a minimal shared Log Analytics workspace
The landing zone SHALL deploy one shared Log Analytics workspace for foundational platform diagnostics in the platform resource group so operators have a central query target during deployment verification and break-glass investigation.

#### Scenario: Foundational platform deployment includes central logging
- **WHEN** the landing-zone foundation is deployed with the observability baseline enabled
- **THEN** one shared Log Analytics workspace is created in the platform resource group for the landing zone

#### Scenario: Operators need a central diagnostics target
- **WHEN** an operator investigates a landing-zone deployment or platform incident
- **THEN** the deployment outputs identify the shared workspace used for foundational diagnostics

### Requirement: The Log Analytics baseline MUST use low-cost defaults
The landing zone MUST configure the shared Log Analytics workspace with low-cost defaults that keep the baseline intentionally lean, including short retention and an explicit ingestion guardrail suitable for foundational resources rather than workloads.

#### Scenario: Default observability settings are applied
- **WHEN** the landing zone deploys the shared workspace without override values
- **THEN** the workspace uses the landing zone's minimal retention and ingestion settings instead of long-history or open-ended defaults

#### Scenario: Higher-cost observability settings are proposed
- **WHEN** an operator or contributor increases retention or ingestion allowances beyond the landing zone baseline
- **THEN** the change is treated as an explicit cost-affecting decision rather than an implicit default

### Requirement: Selected foundational resources MUST send diagnostics to the shared workspace
The landing zone MUST route diagnostics from selected foundational resources to the shared Log Analytics workspace, including the shared Key Vault, the Point-to-Site VPN gateway, and runner platform resources that are deployed by the foundation.

#### Scenario: Shared platform secrets are investigated
- **WHEN** the shared Key Vault is deployed
- **THEN** its supported diagnostics are sent to the shared Log Analytics workspace

#### Scenario: Operator connectivity is investigated
- **WHEN** the Point-to-Site VPN gateway is deployed
- **THEN** its supported diagnostics are sent to the shared Log Analytics workspace

#### Scenario: Runner platform resources are enabled
- **WHEN** the runner VM scale set and autoscaler resources are deployed
- **THEN** their supported diagnostics are sent to the shared Log Analytics workspace

### Requirement: The observability baseline MUST remain scoped to foundational resources
The landing zone MUST keep the initial Log Analytics baseline scoped to shared platform resources and MUST NOT automatically onboard workload spokes or unrelated future services by default.

#### Scenario: A workload spoke is added
- **WHEN** a new workload spoke is onboarded
- **THEN** the spoke is not automatically configured to send diagnostics to the shared Log Analytics workspace unless a later requirement adds that behavior

#### Scenario: Operators review the observability baseline
- **WHEN** the baseline scope is documented
- **THEN** it is described as a foundational shared-platform logging baseline rather than a full monitoring platform
