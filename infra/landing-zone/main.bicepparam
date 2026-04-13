using './main.bicep'

param primaryLocation = 'westeurope'
param landingZoneName = 'hexlz'
param environment = 'dev'
param platformOwner = 'platform-team'
param platformCostCenter = 'shared-platform'
param tags = {
  'alz:managedBy': 'github-actions'
  'alz:sourceRepo': 'hexmaster-waf-foundation'
}
param diagnosticsWorkspaceResourceId = ''
param budgetAmount = 150
param budgetStartDate = '2025-01-01T00:00:00Z'
param budgetContactEmails = [
  'platform-ops@example.com'
]

param hubNetworkConfig = {
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

param operatorConnectivityConfig = {
  vpnGatewaySku: 'VpnGw1'
  vpnClientAddressPool: '172.20.250.0/24'
  entraTenantId: '11111111-1111-1111-1111-111111111111'
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

param sharedServicesConfig = {
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

param runnerExecutionConfig = {
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

param workloadSpokes = []
