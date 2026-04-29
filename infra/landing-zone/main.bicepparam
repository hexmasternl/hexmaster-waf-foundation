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

param hubNetworkConfig = {
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

param operatorConnectivityConfig = {
  vpnGatewaySku: 'VpnGw1AZ'
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
        'runnerInfrastructure'
      ]
    spokeReachabilityRequirement: 'Spokes that require operator access must peer to the hub with allowGatewayTransit and useRemoteGateways enabled.'
  }
}

param sharedServicesConfig = {
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
  deployRunnerPool: true
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
  adminPublicKey: 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN2r9UNWt105Ey7KDf4ZZ85B5PGCA//FIe52EvL2nO0S runneradmin@hexmaster-lz'
  minRunners: 0
  maxRunners: 10
  githubPatSecretName: 'github-actions-pat'
  githubWebhookSecretName: 'github-webhook-secret'
  registrationTokenApiUrl: 'https://api.github.com/orgs/hexmasternl/actions/runners/registration-token'
}

param observabilityConfig = {
  enabled: true
  workspaceSku: 'PerGB2018'
  retentionInDays: 30
  dailyQuotaGb: 1
  logAnalyticsDestinationType: 'Dedicated'
  runnerVmssGuestTelemetry: {
    enabled: true
  }
}

param workloadSpokes = []
