## ADDED Requirements

### Requirement: Workloads SHALL be hosted in separate spoke VNets
The landing zone SHALL host application and workload environments in separate spoke VNets rather than in the hub so that workload boundaries remain distinct from shared platform boundaries.

#### Scenario: A new workload environment is onboarded
- **WHEN** a new workload is added to the landing zone
- **THEN** it is assigned to a spoke VNet instead of being placed directly in the hub

### Requirement: Spokes MUST connect to the hub through a controlled peering model
Workload spokes MUST use a defined peering model to consume shared platform services and approved connectivity paths from the hub.

#### Scenario: A spoke requires access to a hub-hosted service
- **WHEN** a workload consumes a shared platform capability such as the central registry
- **THEN** the spoke reaches the service through the defined hub-and-spoke peering model

### Requirement: Spoke connectivity MUST preserve isolation boundaries
The landing zone MUST define allowed traffic flows between spokes and the hub so that workloads can consume shared services without collapsing isolation between runner, platform, and application trust zones.

#### Scenario: Multiple workloads consume shared platform services
- **WHEN** two or more spoke VNets use hub-hosted platform services
- **THEN** the connectivity model preserves workload isolation while allowing only the approved shared-service flows
