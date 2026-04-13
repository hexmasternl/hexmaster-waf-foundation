## ADDED Requirements

### Requirement: The landing zone SHALL host shared platform services in the hub
The landing zone SHALL define a hub-hosted shared-services model for platform capabilities that are consumed by multiple workload spokes.

#### Scenario: A shared platform capability is introduced
- **WHEN** a platform capability is intended for use by multiple workloads
- **THEN** it is hosted through the shared-services model rather than duplicated by default in each spoke

### Requirement: A central container registry MUST be provided
The landing zone MUST provide a central Azure Container Registry that is consumable by the runner platform and future workload spokes through the defined network connectivity model.

#### Scenario: A runner or workload needs platform images
- **WHEN** an authorized runner job or workload consumes a shared container image
- **THEN** the image is retrieved from the central Azure Container Registry

### Requirement: Shared services SHOULD be privately reachable by default
The landing zone MUST define private connectivity and name-resolution patterns for shared services when those services are intended for private runner or workload access.

#### Scenario: A shared service is consumed privately
- **WHEN** a shared service is designated for private consumption from the landing zone network
- **THEN** the service is exposed through the landing zone private connectivity and DNS model
