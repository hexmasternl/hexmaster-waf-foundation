## ADDED Requirements

### Requirement: Operators SHALL have low-cost private access to the landing zone
The landing zone SHALL provide a low-cost private operator access path using Point-to-Site VPN into the hub so that administrators can reach platform resources during investigation and recovery scenarios.

#### Scenario: An operator needs direct network access
- **WHEN** an authorized operator needs to investigate or recover a platform issue
- **THEN** the operator can connect through the defined VPN access path into the hub network

### Requirement: Break-glass access MUST reach dependent platform resources
The break-glass access model MUST provide operator reachability to the platform resources that are necessary to diagnose failures, including shared services in the hub and permitted resources in peered spokes.

#### Scenario: A failure affects a workload that depends on the hub
- **WHEN** an operator connects through the break-glass access path
- **THEN** the operator can reach the permitted hub and spoke resources needed for diagnosis according to the platform connectivity rules
