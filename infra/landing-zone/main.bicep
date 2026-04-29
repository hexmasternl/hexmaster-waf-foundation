targetScope = 'subscription'

@description('Azure region used for landing-zone metadata and subscription-scope deployments.')
param primaryLocation string

@description('Short landing-zone identifier used in names and tags.')
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

@description('Additional tags merged into the landing-zone resource tags.')
param tags object = {}

@secure()
@description('Optional GitHub organization PAT value that the deployment seeds into the shared platform Key Vault.')
param runnerBootstrapGitHubPat string = ''

@secure()
@description('Optional GitHub webhook shared secret seeded into the shared platform Key Vault for the runner autoscaler.')
param runnerBootstrapGitHubWebhookSecret string = ''

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
    runnerInfrastructure: '10.20.4.0/23'
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
param operatorConnectivityConfig object

@description('Shared platform service configuration for the hub-hosted secret store and consumption of the existing central registry.')
param sharedServicesConfig object = {
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

@description('Runner execution platform configuration for the dedicated GitHub runner VM scale set and webhook autoscaler.')
param runnerExecutionConfig object = {
  deployRunnerPool: false
  githubUrl: 'https://github.com/hexmasternl'
  owner: 'hexmasternl'
  repositories: [
    'hexmaster-waf-foundation'
  ]
  runnerLabels: [
    'vmss'
  ]
  runnerGroup: 'HexMaster Landingzone'
  runnerVersion: '2.333.1'
  vmSku: 'Standard_D2as_v5'
  osDiskSizeGb: 64
  adminUsername: 'runneradmin'
  adminPublicKey: ''
  minRunners: 0
  maxRunners: 10
  githubPatSecretName: 'github-actions-pat'
  githubWebhookSecretName: 'github-webhook-secret'
  registrationTokenApiUrl: 'https://api.github.com/orgs/hexmasternl/actions/runners/registration-token'
}

@description('Minimal observability baseline configuration for the shared Log Analytics workspace and foundational diagnostics.')
param observabilityConfig object = {
  enabled: true
  workspaceSku: 'PerGB2018'
  retentionInDays: 30
  dailyQuotaGb: 1
  logAnalyticsDestinationType: 'Dedicated'
  runnerVmssGuestTelemetry: {
    enabled: true
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
var monitoringResourceGroupName = 'rg-${prefix}-monitoring-${locationToken}'
var runnerResourceGroupName = 'rg-${prefix}-runners-${locationToken}'
var hubVnetName = 'vnet-${prefix}-hub-${locationToken}'
var sharedServicesSubnetName = 'snet-${prefix}-shared-services'
var privateEndpointsSubnetName = 'snet-${prefix}-private-endpoints'
var runnerInfrastructureSubnetName = 'snet-${prefix}-runners'
var runnerAutoscalerIntegrationSubnetName = 'snet-${prefix}-runner-autoscaler'
var dnsResolverInboundSubnetName = 'snet-${prefix}-dns-inbound'
var dnsResolverOutboundSubnetName = 'snet-${prefix}-dns-outbound'
var vpnGatewayPublicIpName = 'pip-${prefix}-vpn-az-${locationToken}'
var vpnGatewayName = 'vpngw-${prefix}-${locationToken}'
var dnsResolverName = 'dnspr-${prefix}-hub-${locationToken}'
var containerRegistryName = 'nvv54gsk4pteu'
var containerRegistryResourceGroupName = 'mvp-int-env'
var platformKeyVaultName = take('kv-${prefix}-${locationToken}', 24)
var logAnalyticsWorkspaceName = take('law-${prefix}-${locationToken}', 63)
var applicationInsightsName = take('appi-${prefix}-${locationToken}', 260)
var runnerScaleSetName = 'vmss-${prefix}-github'
var runnerExecutionIdentityName = 'id-${prefix}-runner-exec'
var runnerAutoscalerFunctionAppName = take('func-${prefix}-runner-${locationToken}', 60)
var runnerPoolEnabled = runnerExecutionConfig.deployRunnerPool && !empty(runnerExecutionConfig.adminPublicKey)
var workloadSpokeDefinitions = [for spoke in workloadSpokes: {
  name: spoke.name
  token: toLower(replace(replace(spoke.name, ' ', '-'), '_', '-'))
  resourceGroupName: 'rg-${prefix}-spoke-${toLower(replace(replace(spoke.name, ' ', '-'), '_', '-'))}-${locationToken}'
  vnetName: 'vnet-${prefix}-${toLower(replace(replace(spoke.name, ' ', '-'), '_', '-'))}-${locationToken}'
  addressPrefixes: spoke.addressPrefixes
  subnetPrefixes: spoke.subnetPrefixes
}]

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

resource monitoringResourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: monitoringResourceGroupName
  location: primaryLocation
  tags: union(requiredTags, {
    'alz:lifecycle': 'monitoring'
  })
}

resource runnerResourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: runnerResourceGroupName
  location: primaryLocation
  tags: union(requiredTags, {
    'alz:lifecycle': 'runner-platform'
  })
}

module hubNetwork '../modules/connectivity/hub-network.bicep' = {
  name: 'hub-network-foundation'
  scope: connectivityResourceGroup
  params: {
    location: primaryLocation
    tags: requiredTags
    vnetName: hubVnetName
      subnetNames: {
        sharedServices: sharedServicesSubnetName
        privateEndpoints: privateEndpointsSubnetName
        runnerInfrastructure: runnerInfrastructureSubnetName
        runnerAutoscalerIntegration: runnerAutoscalerIntegrationSubnetName
        dnsResolverInbound: dnsResolverInboundSubnetName
        dnsResolverOutbound: dnsResolverOutboundSubnetName
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
    gatewayPublicIpName: vpnGatewayPublicIpName
    virtualNetworkGatewayName: vpnGatewayName
    gatewaySubnetId: hubNetwork.outputs.foundation.subnetIds.gateway
    vpnGatewaySku: operatorConnectivityConfig.vpnGatewaySku
    vpnClientAddressPool: operatorConnectivityConfig.vpnClientAddressPool
    entraTenantId: operatorConnectivityConfig.entraTenantId
    entraAudience: operatorConnectivityConfig.entraAudience
    breakGlass: operatorConnectivityConfig.breakGlass
  }
}

module dnsResolver '../modules/connectivity/dns-resolver.bicep' = {
  name: 'hub-dns-resolver'
  scope: connectivityResourceGroup
  params: {
    location: primaryLocation
    tags: requiredTags
    resolverName: dnsResolverName
    hubVnetId: hubNetwork.outputs.foundation.vnetId
    inboundSubnetId: hubNetwork.outputs.foundation.subnetIds.dnsResolverInbound
    outboundSubnetId: hubNetwork.outputs.foundation.subnetIds.dnsResolverOutbound
  }
}

module sharedServices '../modules/platform/shared-services.bicep' = {  name: 'shared-platform-services'
  scope: platformResourceGroup
  params: {
    location: primaryLocation
    tags: requiredTags
    hubVirtualNetworkId: hubNetwork.outputs.foundation.vnetId
    privateEndpointSubnetId: hubNetwork.outputs.foundation.subnetIds.privateEndpoints
    containerRegistryName: containerRegistryName
    containerRegistryResourceGroupName: containerRegistryResourceGroupName
    keyVaultName: platformKeyVaultName
    runnerBootstrapGitHubPat: runnerBootstrapGitHubPat
    runnerBootstrapGitHubPatSecretName: runnerExecutionConfig.githubPatSecretName
    runnerBootstrapGitHubWebhookSecret: runnerBootstrapGitHubWebhookSecret
    runnerBootstrapGitHubWebhookSecretName: runnerExecutionConfig.githubWebhookSecretName
    sharedServicesConfig: sharedServicesConfig
  }
}

module runnerExecution '../modules/platform/runner-execution.bicep' = {
  name: 'runner-execution-platform'
  scope: runnerResourceGroup
  params: {
    location: primaryLocation
    tags: requiredTags
    runnerScaleSetName: runnerScaleSetName
    runnerExecutionIdentityName: runnerExecutionIdentityName
    runnerAutoscalerFunctionAppName: runnerAutoscalerFunctionAppName
    keyVaultName: platformKeyVaultName
    keyVaultResourceGroupName: platformResourceGroupName
    infrastructureSubnetId: hubNetwork.outputs.foundation.subnetIds.runnerInfrastructure
    autoscalerIntegrationSubnetId: hubNetwork.outputs.foundation.subnetIds.runnerAutoscalerIntegration
    runnerExecutionConfig: runnerExecutionConfig
    applicationInsightsConnectionString: observability.outputs.applicationInsights.connectionString
  }
  dependsOn: [
    sharedServices
  ]
}

module observability '../modules/platform/observability.bicep' = {
  name: 'landing-zone-observability'
  scope: monitoringResourceGroup
  params: {
    location: primaryLocation
    tags: requiredTags
    workspaceName: logAnalyticsWorkspaceName
    applicationInsightsName: applicationInsightsName
    observabilityConfig: observabilityConfig
  }
  dependsOn: [
    sharedServices
  ]
}

module observabilityConnectivityDiagnostics '../modules/platform/observability-connectivity-diagnostics.bicep' = {
  name: 'landing-zone-observability-connectivity'
  scope: connectivityResourceGroup
  params: {
    workspaceId: observability.outputs.workspace.id
    observabilityConfig: observabilityConfig
    virtualNetworkGatewayName: vpnGatewayName
  }
  dependsOn: [
    operatorConnectivity
  ]
}

module observabilityPlatformDiagnostics '../modules/platform/observability-platform-diagnostics.bicep' = {
  name: 'landing-zone-observability-platform'
  scope: platformResourceGroup
  params: {
    workspaceId: observability.outputs.workspace.id
    observabilityConfig: observabilityConfig
    keyVaultName: platformKeyVaultName
  }
  dependsOn: [
    sharedServices
  ]
}

module observabilityRunnerDiagnostics '../modules/platform/observability-runner-diagnostics.bicep' = if (runnerPoolEnabled) {
  name: 'landing-zone-observability-runner'
  scope: runnerResourceGroup
  params: {
    workspaceId: observability.outputs.workspace.id
    observabilityConfig: observabilityConfig
    runnerDiagnostics: {
      vmScaleSetName: runnerExecution.outputs.runnerPlatform.vmScaleSet.name
      functionAppName: runnerExecution.outputs.runnerPlatform.autoscaler.functionApp.name
      autoscalerStorageAccountName: runnerExecution.outputs.runnerPlatform.autoscaler.storageAccount.name
      executionIdentityResourceId: runnerExecution.outputs.runnerPlatform.identities.execution.resourceId
      guestTelemetryDataCollectionRuleId: observability.outputs.runnerVmssGuestTelemetry.dataCollectionRuleId
    }
  }
}

module runnerAmaMetricsPublisherAssignment '../modules/platform/observability-ama-role-assignment.bicep' = if (runnerPoolEnabled) {
  name: 'runner-ama-metrics-publisher'
  scope: monitoringResourceGroup
  params: {
    principalId: runnerExecution.outputs.runnerPlatform.identities.execution.principalId
    dataCollectionRuleName: observability.outputs.runnerVmssGuestTelemetry.dataCollectionRuleName
  }
}

module runnerExecutionKeyVaultAssignment '../modules/platform/key-vault-secret-reader-assignment.bicep' = if (runnerPoolEnabled) {
  name: 'runner-execution-key-vault-assignment'
  scope: platformResourceGroup
  params: {
    keyVaultName: platformKeyVaultName
    principalId: runnerExecution.outputs.runnerPlatform.identities.execution.principalId
    roleAssignmentGuid: guid(platformKeyVaultName, runnerExecutionIdentityName, 'runner-key-vault-secrets-user')
  }
}

module runnerAutoscalerKeyVaultAssignment '../modules/platform/key-vault-secret-reader-assignment.bicep' = if (runnerPoolEnabled) {
  name: 'runner-autoscaler-key-vault-assignment'
  scope: platformResourceGroup
  params: {
    keyVaultName: platformKeyVaultName
    principalId: runnerExecution.outputs.runnerPlatform.autoscaler.functionApp.principalId
    roleAssignmentGuid: guid(platformKeyVaultName, runnerAutoscalerFunctionAppName, 'runner-autoscaler-key-vault-secrets-user')
  }
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

output requiredTags object = requiredTags
output hubNetworkFoundation object = hubNetwork.outputs.foundation
output dnsResolverFoundation object = dnsResolver.outputs.resolver
output operatorConnectivity object = operatorConnectivity.outputs.connectivity
output sharedPlatformServices object = sharedServices.outputs.sharedServices
output runnerExecutionPlatform object = runnerExecution.outputs.runnerPlatform
output observabilityBaseline object = {
  enabled: observabilityConfig.enabled
  monitoringResourceGroupName: monitoringResourceGroupName
  workspace: observability.outputs.workspace
  applicationInsights: observability.outputs.applicationInsights
  lowCostDefaults: observability.outputs.lowCostDefaults
  coveredResources: observabilityConfig.enabled ? concat([
    'Shared Key Vault'
    'Point-to-Site VPN gateway'
  ], runnerPoolEnabled ? [
    'Runner Function App (logs, metrics, App Insights traces)'
    'Runner VM scale set metrics'
    'Runner VM scale set guest logs and telemetry'
    'Runner autoscaler storage account services'
  ] : []) : []
  operatorNotes: observabilityConfig.enabled ? [
    'Log Analytics workspace and Application Insights are in the dedicated monitoring resource group.'
    'The Function App sends all structured logs and exceptions to Application Insights via APPLICATIONINSIGHTS_CONNECTION_STRING.'
    'Runner VMs ship syslog (daemon, user, cron, auth, kern) and detailed metrics to the workspace via the Azure Monitor Agent.'
    'The baseline is intentionally limited to foundational shared-platform resources and does not onboard workload spokes by default.'
    'Runner diagnostics are only enabled when the runner pool is deployed with a real admin SSH key.'
  ] : [
    'Minimal observability is disabled for this deployment.'
  ]
}
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
