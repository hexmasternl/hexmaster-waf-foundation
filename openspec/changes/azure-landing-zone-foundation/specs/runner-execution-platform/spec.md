## ADDED Requirements

### Requirement: GitHub self-hosted runners SHALL execute on Azure Container Apps Jobs
The landing zone SHALL host GitHub self-hosted runners using Azure Container Apps Jobs so that runner execution is ephemeral and does not require a permanently provisioned VM fleet.

#### Scenario: A GitHub Actions job requires a private runner
- **WHEN** a workflow targets the landing-zone self-hosted runner platform
- **THEN** the workflow is executed by a runner implemented through Azure Container Apps Jobs

### Requirement: Runner execution MUST have private access to landing-zone resources
The runner platform MUST integrate with the landing-zone network so that authorized workflows can reach hub-hosted services and permitted Azure resources without traversing a public management path.

#### Scenario: A workflow needs to reach a private platform service
- **WHEN** a runner job executes a deployment or operational task
- **THEN** it can reach the permitted private service through the landing-zone network model

### Requirement: Runner execution MUST use isolated identity and secret boundaries
The runner platform MUST define workload identity, image retrieval, and secret-handling boundaries that separate runner execution from operator access and from future workload identities.

#### Scenario: A runner job accesses Azure resources
- **WHEN** a runner job authenticates to Azure or retrieves required secrets
- **THEN** it uses the runner platform's defined identity and secret model rather than shared operator credentials
