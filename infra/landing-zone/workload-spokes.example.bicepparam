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

param workloadSpokes = [
  {
    name: 'payments'
    addressPrefixes: [
      '10.32.0.0/22'
    ]
    subnetPrefixes: {
      workload: '10.32.0.0/24'
      privateEndpoints: '10.32.1.0/24'
      reservedFuture: '10.32.2.0/23'
    }
  }
  {
    name: 'analytics'
    addressPrefixes: [
      '10.32.4.0/22'
    ]
    subnetPrefixes: {
      workload: '10.32.4.0/24'
      privateEndpoints: '10.32.5.0/24'
      reservedFuture: '10.32.6.0/23'
    }
  }
]
