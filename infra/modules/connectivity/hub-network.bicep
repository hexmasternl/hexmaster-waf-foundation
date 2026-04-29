targetScope = 'resourceGroup'

@description('Azure region for the hub network foundation.')
param location string

@description('Tags applied to the hub network resources.')
param tags object = {}

@description('Name of the hub virtual network.')
param vnetName string

@description('Subnet names used for the hub platform network.')
param subnetNames object

@description('Hub platform network configuration, including address ranges, subnet prefixes, and DNS baseline metadata.')
param hubNetworkConfig object

@description('Address pool assigned to Point-to-Site VPN operators.')
param vpnClientAddressPool string

var subnetPrefixes = hubNetworkConfig.subnetPrefixes

resource dnsResolverInboundNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-${subnetNames.dnsResolverInbound}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowDnsFromVirtualNetworkTcp'
        properties: {
          description: 'Allows TCP DNS queries from hub and peered spoke VNets.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '53'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: subnetPrefixes.dnsResolverInbound
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowDnsFromVirtualNetworkUdp'
        properties: {
          description: 'Allows UDP DNS queries from hub and peered spoke VNets.'
          protocol: 'Udp'
          sourcePortRange: '*'
          destinationPortRange: '53'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: subnetPrefixes.dnsResolverInbound
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowDnsFromVpnClientsTcp'
        properties: {
          description: 'Allows TCP DNS queries from P2S VPN operators so they resolve private hostnames when connected.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '53'
          sourceAddressPrefix: vpnClientAddressPool
          destinationAddressPrefix: subnetPrefixes.dnsResolverInbound
          access: 'Allow'
          priority: 200
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowDnsFromVpnClientsUdp'
        properties: {
          description: 'Allows UDP DNS queries from P2S VPN operators so they resolve private hostnames when connected.'
          protocol: 'Udp'
          sourcePortRange: '*'
          destinationPortRange: '53'
          sourceAddressPrefix: vpnClientAddressPool
          destinationAddressPrefix: subnetPrefixes.dnsResolverInbound
          access: 'Allow'
          priority: 210
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyInternetInbound'
        properties: {
          description: 'Prevents the DNS resolver inbound endpoint from being reachable from the internet.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4000
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource sharedServicesNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-${subnetNames.sharedServices}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowOperatorP2SInbound'
        properties: {
          description: 'Allows break-glass operators from the P2S pool to reach hub shared services.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: vpnClientAddressPool
          destinationAddressPrefix: subnetPrefixes.sharedServices
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyInternetInbound'
        properties: {
          description: 'Keeps shared services private by default.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4000
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource privateEndpointsNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-${subnetNames.privateEndpoints}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowOperatorP2SInbound'
        properties: {
          description: 'Allows break-glass operators to reach private endpoints for diagnostics.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: vpnClientAddressPool
          destinationAddressPrefix: subnetPrefixes.privateEndpoints
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyInternetInbound'
        properties: {
          description: 'Prevents direct internet reachability to private endpoints.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4000
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource runnerInfrastructureNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-${subnetNames.runnerInfrastructure}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowOperatorP2SInbound'
        properties: {
          description: 'Allows break-glass operators to reach runner VMs over SSH.'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: vpnClientAddressPool
          destinationAddressPrefix: subnetPrefixes.runnerInfrastructure
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyInternetInbound'
        properties: {
          description: 'Keeps the runner subnet private by default.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 4000
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource sharedServicesRouteTable 'Microsoft.Network/routeTables@2024-05-01' = {
  name: 'rt-${subnetNames.sharedServices}'
  location: location
  tags: tags
  properties: {
    disableBgpRoutePropagation: false
    routes: []
  }
}

resource privateEndpointsRouteTable 'Microsoft.Network/routeTables@2024-05-01' = {
  name: 'rt-${subnetNames.privateEndpoints}'
  location: location
  tags: tags
  properties: {
    disableBgpRoutePropagation: false
    routes: []
  }
}

resource runnerInfrastructureRouteTable 'Microsoft.Network/routeTables@2024-05-01' = {
  name: 'rt-${subnetNames.runnerInfrastructure}'
  location: location
  tags: tags
  properties: {
    disableBgpRoutePropagation: false
    routes: []
  }
}

resource runnerSubnetNatPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'pip-${subnetNames.runnerInfrastructure}-nat'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource runnerSubnetNatGateway 'Microsoft.Network/natGateways@2024-05-01' = {
  name: 'nat-${subnetNames.runnerInfrastructure}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIpAddresses: [
      {
        id: runnerSubnetNatPublicIp.id
      }
    ]
    idleTimeoutInMinutes: 10
  }
}

resource hubVnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: hubNetworkConfig.addressPrefixes
    }
    dhcpOptions: {
      dnsServers: hubNetworkConfig.dnsBaseline.customDnsServers
    }
    subnets: [
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: subnetPrefixes.gateway
        }
      }
      {
        name: subnetNames.sharedServices
        properties: {
          addressPrefix: subnetPrefixes.sharedServices
          networkSecurityGroup: {
            id: sharedServicesNsg.id
          }
          routeTable: {
            id: sharedServicesRouteTable.id
          }
        }
      }
      {
        name: subnetNames.privateEndpoints
        properties: {
          addressPrefix: subnetPrefixes.privateEndpoints
          networkSecurityGroup: {
            id: privateEndpointsNsg.id
          }
          routeTable: {
            id: privateEndpointsRouteTable.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: subnetNames.runnerInfrastructure
        properties: {
          addressPrefix: subnetPrefixes.runnerInfrastructure
          networkSecurityGroup: {
            id: runnerInfrastructureNsg.id
          }
          routeTable: {
            id: runnerInfrastructureRouteTable.id
          }
          natGateway: {
            id: runnerSubnetNatGateway.id
          }
        }
      }
      {
        name: subnetNames.dnsResolverInbound
        properties: {
          addressPrefix: subnetPrefixes.dnsResolverInbound
          networkSecurityGroup: {
            id: dnsResolverInboundNsg.id
          }
          delegations: [
            {
              name: 'dns-resolver-inbound'
              properties: {
                serviceName: 'Microsoft.Network/dnsResolvers'
              }
            }
          ]
        }
      }
      {
        name: subnetNames.dnsResolverOutbound
        properties: {
          addressPrefix: subnetPrefixes.dnsResolverOutbound
          delegations: [
            {
              name: 'dns-resolver-outbound'
              properties: {
                serviceName: 'Microsoft.Network/dnsResolvers'
              }
            }
          ]
        }
      }
    ]
  }
}

output foundation object = {
  vnetName: hubVnet.name
  vnetId: hubVnet.id
  subnetIds: {
    gateway: resourceId('Microsoft.Network/virtualNetworks/subnets', hubVnet.name, 'GatewaySubnet')
    sharedServices: resourceId('Microsoft.Network/virtualNetworks/subnets', hubVnet.name, subnetNames.sharedServices)
    privateEndpoints: resourceId('Microsoft.Network/virtualNetworks/subnets', hubVnet.name, subnetNames.privateEndpoints)
    runnerInfrastructure: resourceId('Microsoft.Network/virtualNetworks/subnets', hubVnet.name, subnetNames.runnerInfrastructure)
    dnsResolverInbound: resourceId('Microsoft.Network/virtualNetworks/subnets', hubVnet.name, subnetNames.dnsResolverInbound)
    dnsResolverOutbound: resourceId('Microsoft.Network/virtualNetworks/subnets', hubVnet.name, subnetNames.dnsResolverOutbound)
  }
  routeTables: {
    sharedServices: sharedServicesRouteTable.id
    privateEndpoints: privateEndpointsRouteTable.id
    runnerInfrastructure: runnerInfrastructureRouteTable.id
  }
  networkSecurityGroups: {
    sharedServices: sharedServicesNsg.id
    privateEndpoints: privateEndpointsNsg.id
    runnerInfrastructure: runnerInfrastructureNsg.id
    dnsResolverInbound: dnsResolverInboundNsg.id
  }
  natGateway: {
    id: runnerSubnetNatGateway.id
    publicIpAddressId: runnerSubnetNatPublicIp.id
  }
  addressPlan: {
    hubAddressPrefixes: hubNetworkConfig.addressPrefixes
    subnetPrefixes: subnetPrefixes
    reservedAddressPrefixes: hubNetworkConfig.reservedAddressPrefixes
    futureSpokeSupernet: hubNetworkConfig.futureSpokeSupernet
    notes: [
      'The hub is reserved for platform connectivity, shared services, and runner infrastructure.'
      'The runner subnet is dedicated to the VM scale set and keeps runner compute separate from shared services and operators.'
      'The future spoke supernet is intentionally separate from the hub VNet to keep peering straightforward.'
      'DNS resolver subnets (10.20.3.0/28 inbound, 10.20.3.16/28 outbound) are carved from the formerly reserved futurePlatformDns block (10.20.3.0/24).'
    ]
  }
  dnsBaseline: {
    resolverMode: hubNetworkConfig.dnsBaseline.resolverMode
    privateZonePlacement: hubNetworkConfig.dnsBaseline.privateZonePlacement
    spokeLinkMode: hubNetworkConfig.dnsBaseline.spokeLinkMode
    customDnsServers: hubNetworkConfig.dnsBaseline.customDnsServers
    notes: [
      'Hub VNet DHCP DNS is set to the DNS Private Resolver inbound endpoint IP when resolverMode is PrivateResolver.'
      'The resolver forwards unknown queries to Azure DNS (168.63.129.16) by default — private DNS zones linked to the hub VNet resolve automatically.'
      'Keep DNS central in the hub so future spoke onboarding does not require per-spoke resolvers.'
    ]
  }
}
