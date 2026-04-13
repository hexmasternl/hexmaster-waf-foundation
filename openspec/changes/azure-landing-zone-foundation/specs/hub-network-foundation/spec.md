## ADDED Requirements

### Requirement: The landing zone SHALL provide a hub VNet foundation
The landing zone SHALL provide a hub VNet that serves as the shared platform network for operator access, shared services, and runner execution. The hub address plan MUST leave room for future workload spokes and future routing controls without requiring renumbering.

#### Scenario: The initial network is designed
- **WHEN** the landing-zone network foundation is defined
- **THEN** a hub VNet exists with non-overlapping address space reserved for future spokes and growth

### Requirement: The hub SHALL use dedicated subnets for platform roles
The hub SHALL segment platform roles into dedicated subnets for VPN ingress, shared services, private connectivity, and Azure Container Apps infrastructure so that platform components do not share a flat trust boundary.

#### Scenario: Platform components are placed in the hub
- **WHEN** operator access, shared services, and runner infrastructure are deployed
- **THEN** they are assigned to role-specific subnets rather than a single shared subnet

### Requirement: The network foundation MUST be spoke-ready
The hub network foundation MUST support future spoke VNets through peering-ready address planning, DNS patterns, and baseline routing boundaries.

#### Scenario: A future workload VNet is introduced
- **WHEN** a new workload spoke is onboarded
- **THEN** it can peer with the hub without requiring the hub VNet to be readdressed or resegmented
