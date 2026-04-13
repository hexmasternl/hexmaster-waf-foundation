targetScope = 'subscription'

@description('Azure region used for landing-zone metadata and subscription-scope deployments.')
param primaryLocation string

@description('Short landing-zone identifier used in names, tags, and budget resources.')
@minLength(2)
@maxLength(12)
param landingZoneName string

@description('Environment stamp for the landing zone.')
@allowed([
  'dev'
  'test'
  'prod'
])
param environment string = 'dev'

@description('Owning team or platform contact for the shared landing zone.')
param platformOwner string

@description('Cost center, cost code, or internal chargeback reference.')
param platformCostCenter string

@description('Additional tags merged into the shared governance baseline.')
param tags object = {}

@description('Existing Log Analytics workspace resource ID used for diagnostic settings defaults. Leave empty until observability resources exist.')
param diagnosticsWorkspaceResourceId string = ''

@description('Monthly subscription budget amount in the subscription billing currency.')
@minValue(1)
param budgetAmount int = 150

@description('Budget period start date in ISO 8601 format, for example 2025-01-01T00:00:00Z.')
param budgetStartDate string

@description('Email recipients for budget threshold notifications.')
param budgetContactEmails array

@description('Hub platform network configuration, including address planning and DNS baseline metadata.')
param hubNetworkConfig object = {
  addressPrefixes: [
    '10.20.0.0/20'
  ]
  futureSpokeSupernet: '10.32.0.0/12'
  subnetPrefixes: {
    gateway: '10.20.0.0/24'
    sharedServices: '10.20.1.0/24'
    privateEndpoints: '10.20.2.0/24'
    containerAppsInfrastructure: '10.20.4.0/23'
  }
  reservedAddressPrefixes: {
    futurePlatformDns: '10.20.3.0/24'
    futurePlatformSecurity: '10.20.6.0/23'
    futureHubExpansion: '10.20.8.0/21'
  }
  dnsBaseline: {
    resolverMode: 'AzureProvided'
    privateZonePlacement: 'Hub'
    spokeLinkMode: 'LinkToHubPrivateZones'
    customDnsServers: []
  }
}

@description('Operator connectivity configuration for the Point-to-Site VPN path.')
param operatorConnectivityConfig object = {
  vpnGatewaySku: 'VpnGw1'
  vpnClientAddressPool: '172.20.250.0/24'
  entraTenantId: '00000000-0000-0000-0000-000000000000'
  entraAudience: 'c632b3df-fb67-4d84-bdcf-b95ad541b5c8'
  breakGlass: {
    primaryClient: 'Azure VPN Client'
    authenticationMode: 'MicrosoftEntraId'
    operatorGroupName: 'alz-platform-operators'
    emergencyAccessGroupName: 'alz-platform-break-glass'
    allowedTargetSubnets: [
      'sharedServices'
      'privateEndpoints'
      'containerAppsInfrastructure'
    ]
    spokeReachabilityRequirement: 'Spokes that require operator access must peer to the hub with allowGatewayTransit and useRemoteGateways enabled.'
  }
}

@description('Shared platform service configuration for the hub-hosted central registry and secret store.')
param sharedServicesConfig object = {
  registry: {
    sku: 'Premium'
    publicNetworkAccess: 'Disabled'
  }
  secretVault: {
    sku: 'standard'
    publicNetworkAccess: 'Disabled'
    enablePurgeProtection: true
  }
  hostingModel: {
    platformResourceGroupPlacement: 'DedicatedPlatformResourceGroup'
    sharedServicesSubnetPurpose: 'HubHostedPlatformServicesOnly'
    privateEndpointSubnetPurpose: 'PrivateEndpointsAndPrivateDnsOnly'
    spokeConsumptionPattern: 'UseHubPrivateDnsLinksAndHubPrivateEndpoints'
  }
}

@description('Runner execution platform configuration for the shared Container Apps environment and GitHub runner job.')
param runnerExecutionConfig object = {
  deployRunnerJob: false
  imageRepository: 'github-actions-runner'
  imageTag: 'latest'
  githubApiUrl: 'https://api.github.com'
  githubUrl: ''
  runnerScope: 'repo'
  owner: ''
  repositories: []
  targetWorkflowQueueLength: 1
  minExecutions: 0
  maxExecutions: 5
  pollingInterval: 30
  replicaTimeout: 1800
  replicaRetryLimit: 0
  replicaCompletionCount: 1
  parallelism: 1
  cpu: 2
  memory: '4Gi'
  githubPatSecretName: 'github-actions-pat'
  githubPatSecretUri: ''
  registrationTokenApiUrl: ''
  environmentNetwork: {
    dockerBridgeCidr: '10.255.0.0/16'
    platformReservedCidr: '10.254.0.0/16'
    platformReservedDnsIP: '10.254.0.10'
  }
}

@description('Optional workload spoke definitions. Each spoke must use non-overlapping prefixes carved from hubNetworkConfig.futureSpokeSupernet and reserve room for workload, private endpoint, and future growth subnets.')
param workloadSpokes array = []

var locationToken = toLower(replace(primaryLocation, ' ', ''))
var prefix = '${landingZoneName}-${environment}'
var requiredTags = union({
  'alz:landingZone': landingZoneName
  'alz:environment': environment
  'alz:owner': platformOwner
  'alz:costCenter': platformCostCenter
  'alz:lifecycle': 'shared-platform'
  'alz:managedBy': 'bicep'
}, tags)
var connectivityResourceGroupName = 'rg-${prefix}-connectivity-${locationToken}'
var platformResourceGroupName = 'rg-${prefix}-platform-${locationToken}'
var hubVnetName = 'vnet-${prefix}-hub-${locationToken}'
var workloadSpokeDefinitions = [for spoke in workloadSpokes: {
  name: spoke.name
  token: toLower(replace(replace(spoke.name, ' ', '-'), '_', '-'))
  resourceGroupName: 'rg-${prefix}-spoke-${toLower(replace(replace(spoke.name, ' ', '-'), '_', '-'))}-${locationToken}'
  vnetName: 'vnet-${prefix}-${toLower(replace(replace(spoke.name, ' ', '-'), '_', '-'))}-${locationToken}'
  addressPrefixes: spoke.addressPrefixes
  subnetPrefixes: spoke.subnetPrefixes
}]

module governanceBaseline '../modules/governance/baseline.bicep' = {
  name: 'governance-baseline'
  params: {
    primaryLocation: primaryLocation
    landingZoneName: landingZoneName
    environment: environment
    platformOwner: platformOwner
    platformCostCenter: platformCostCenter
    tags: tags
    diagnosticsWorkspaceResourceId: diagnosticsWorkspaceResourceId
    budgetAmount: budgetAmount
    budgetStartDate: budgetStartDate
    budgetContactEmails: budgetContactEmails
  }
}

resource connectivityResourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: connectivityResourceGroupName
  location: primaryLocation
  tags: requiredTags
}

resource platformResourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: platformResourceGroupName
  location: primaryLocation
  tags: requiredTags
}

module hubNetwork '../modules/connectivity/hub-network.bicep' = {
  name: 'hub-network-foundation'
  scope: connectivityResourceGroup
  params: {
    location: primaryLocation
    tags: requiredTags
    vnetName: hubVnetName
    subnetNames: {
      sharedServices: governanceBaseline.outputs.baseline.naming.resources.sharedServicesSubnet
      privateEndpoints: governanceBaseline.outputs.baseline.naming.resources.privateEndpointsSubnet
      containerAppsInfrastructure: governanceBaseline.outputs.baseline.naming.resources.runnerInfrastructureSubnet
    }
    hubNetworkConfig: hubNetworkConfig
    vpnClientAddressPool: operatorConnectivityConfig.vpnClientAddressPool
  }
}

resource workloadSpokeResourceGroups 'Microsoft.Resources/resourceGroups@2024-11-01' = [for spoke in workloadSpokeDefinitions: {
  name: spoke.resourceGroupName
  location: primaryLocation
  tags: union(requiredTags, {
    'alz:lifecycle': 'workload-spoke'
    'alz:networkRole': 'workload-spoke'
    'alz:workload': spoke.name
  })
}]

module workloadSpokeModules '../modules/connectivity/workload-spoke.bicep' = [for (spoke, i) in workloadSpokeDefinitions: {
  name: 'workload-spoke-${i}'
  scope: workloadSpokeResourceGroups[i]
  params: {
    location: primaryLocation
    tags: union(requiredTags, {
      'alz:lifecycle': 'workload-spoke'
      'alz:networkRole': 'workload-spoke'
      'alz:workload': spoke.name
    })
    spokeName: spoke.name
    spokeToken: spoke.token
    vnetName: spoke.vnetName
    addressPrefixes: spoke.addressPrefixes
    subnetPrefixes: spoke.subnetPrefixes
    hubAddressPrefixes: hubNetworkConfig.addressPrefixes
    hubSharedServicesPrefix: hubNetworkConfig.subnetPrefixes.sharedServices
    hubPrivateEndpointsPrefix: hubNetworkConfig.subnetPrefixes.privateEndpoints
    futureSpokeSupernet: hubNetworkConfig.futureSpokeSupernet
    vpnClientAddressPool: operatorConnectivityConfig.vpnClientAddressPool
  }
  dependsOn: [
    workloadSpokeResourceGroups[i]
  ]
}]

module hubToSpokePeeringModules '../modules/connectivity/vnet-peering.bicep' = [for (spoke, i) in workloadSpokeDefinitions: {
  name: 'hub-to-spoke-peering-${i}'
  scope: connectivityResourceGroup
  params: {
    localVnetName: hubVnetName
    peeringName: 'peer-${hubVnetName}-to-${spoke.token}'
    remoteVnetId: workloadSpokeModules[i].outputs.spoke.vnetId
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: false
    allowGatewayTransit: true
    useRemoteGateways: false
  }
  dependsOn: [
    workloadSpokeModules[i]
  ]
}]

module spokeToHubPeeringModules '../modules/connectivity/vnet-peering.bicep' = [for (spoke, i) in workloadSpokeDefinitions: {
  name: 'spoke-to-hub-peering-${i}'
  scope: workloadSpokeResourceGroups[i]
  params: {
    localVnetName: spoke.vnetName
    peeringName: 'peer-${spoke.vnetName}-to-${hubVnetName}'
    remoteVnetId: hubNetwork.outputs.foundation.vnetId
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: false
    allowGatewayTransit: false
    useRemoteGateways: true
  }
  dependsOn: [
    workloadSpokeModules[i]
  ]
}]

module operatorConnectivity '../modules/connectivity/operator-connectivity.bicep' = {
  name: 'operator-connectivity'
  scope: connectivityResourceGroup
  params: {
    location: primaryLocation
    tags: requiredTags
    gatewayPublicIpName: governanceBaseline.outputs.baseline.naming.resources.vpnGatewayPublicIp
    virtualNetworkGatewayName: governanceBaseline.outputs.baseline.naming.resources.vpnGateway
    gatewaySubnetId: hubNetwork.outputs.foundation.subnetIds.gateway
    vpnGatewaySku: operatorConnectivityConfig.vpnGatewaySku
    vpnClientAddressPool: operatorConnectivityConfig.vpnClientAddressPool
    entraTenantId: operatorConnectivityConfig.entraTenantId
    entraAudience: operatorConnectivityConfig.entraAudience
    breakGlass: operatorConnectivityConfig.breakGlass
  }
}

module sharedServices '../modules/platform/shared-services.bicep' = {
  name: 'shared-platform-services'
  scope: platformResourceGroup
  params: {
    location: primaryLocation
    tags: requiredTags
    hubVirtualNetworkId: hubNetwork.outputs.foundation.vnetId
    privateEndpointSubnetId: hubNetwork.outputs.foundation.subnetIds.privateEndpoints
    containerRegistryName: governanceBaseline.outputs.baseline.naming.resources.containerRegistry
    keyVaultName: governanceBaseline.outputs.baseline.naming.resources.platformKeyVault
    sharedServicesConfig: sharedServicesConfig
  }
}

module runnerExecution '../modules/platform/runner-execution.bicep' = {
  name: 'runner-execution-platform'
  scope: platformResourceGroup
  params: {
    location: primaryLocation
    tags: requiredTags
    containerAppsEnvironmentName: governanceBaseline.outputs.baseline.naming.resources.containerAppsEnvironment
    runnerJobName: governanceBaseline.outputs.baseline.naming.resources.runnerJob
    runnerExecutionIdentityName: governanceBaseline.outputs.baseline.naming.resources.runnerExecutionIdentity
    runnerRegistryIdentityName: governanceBaseline.outputs.baseline.naming.resources.runnerRegistryIdentity
    containerRegistryName: governanceBaseline.outputs.baseline.naming.resources.containerRegistry
    keyVaultName: governanceBaseline.outputs.baseline.naming.resources.platformKeyVault
    infrastructureSubnetId: hubNetwork.outputs.foundation.subnetIds.containerAppsInfrastructure
    runnerExecutionConfig: runnerExecutionConfig
  }
  dependsOn: [
    sharedServices
  ]
}

var deployedWorkloadSpokes = [for spoke in workloadSpokeDefinitions: {
  name: spoke.name
  resourceGroupName: spoke.resourceGroupName
  vnetName: spoke.vnetName
  addressPrefixes: spoke.addressPrefixes
  subnetPrefixes: spoke.subnetPrefixes
  peering: {
    hubToSpoke: {
      peeringName: 'peer-${hubVnetName}-to-${spoke.token}'
      allowGatewayTransit: true
      allowForwardedTraffic: false
    }
    spokeToHub: {
      peeringName: 'peer-${spoke.vnetName}-to-${hubVnetName}'
      useRemoteGateways: true
      allowForwardedTraffic: false
    }
  }
  allowedHubDestinations: {
    sharedServices: hubNetworkConfig.subnetPrefixes.sharedServices
    privateEndpoints: hubNetworkConfig.subnetPrefixes.privateEndpoints
  }
}]

output governanceBaseline object = governanceBaseline.outputs.baseline
output requiredTags object = governanceBaseline.outputs.requiredTags
output diagnosticsDefaults object = governanceBaseline.outputs.diagnosticsDefaults
output allowedServiceTiers object = governanceBaseline.outputs.allowedServiceTiers
output hubNetworkFoundation object = hubNetwork.outputs.foundation
output operatorConnectivity object = operatorConnectivity.outputs.connectivity
output sharedPlatformServices object = sharedServices.outputs.sharedServices
output runnerExecutionPlatform object = runnerExecution.outputs.runnerPlatform
output workloadSpokeNetworking object = {
  standard: {
    addressSupernet: hubNetworkConfig.futureSpokeSupernet
    requiredSubnets: [
      'workload'
      'privateEndpoints'
    ]
    reservedFuturePrefix: 'Provide subnetPrefixes.reservedFuture in each workloadSpokes entry to keep room for later in-spoke growth.'
    peeringModel: {
      topology: 'HubAndSpokeOnly'
      spokeToSpokePeering: 'NotAllowed'
      hubToSpoke: {
        allowVirtualNetworkAccess: true
        allowForwardedTraffic: false
        allowGatewayTransit: true
      }
      spokeToHub: {
        allowVirtualNetworkAccess: true
        allowForwardedTraffic: false
        useRemoteGateways: true
      }
    }
    allowedHubDestinations: {
      sharedServices: hubNetworkConfig.subnetPrefixes.sharedServices
      privateEndpoints: hubNetworkConfig.subnetPrefixes.privateEndpoints
    }
    isolationNotes: [
      'Workloads stay in separate VNets carved from the reserved spoke supernet and never share the hub VNet.'
      'Subnet NSGs allow hub access only to the shared-services and private-endpoints prefixes and deny traffic to the wider hub and to other spokes.'
      'Break-glass operator reachability comes through the hub VPN gateway and does not require direct spoke-to-spoke trust.'
    ]
  }
  spokes: deployedWorkloadSpokes
}
