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
  entraTenantId: '922cee41-db95-4eff-8022-9b815f545dee'
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
