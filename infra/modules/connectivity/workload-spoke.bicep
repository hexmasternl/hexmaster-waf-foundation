targetScope = 'resourceGroup'

@description('Azure region for the workload spoke network.')
param location string

@description('Tags applied to the workload spoke resources.')
param tags object = {}

@description('Friendly workload name for the spoke.')
param spokeName string

@description('Normalized token used in resource names for the spoke.')
param spokeToken string

@description('Name of the workload spoke virtual network.')
param vnetName string

@description('Address prefixes assigned to the workload spoke VNet.')
param addressPrefixes array

@description('Subnet prefixes used inside the workload spoke.')
param subnetPrefixes object

@description('Hub VNet address prefixes used to deny non-approved platform access.')
param hubAddressPrefixes array

@description('Hub shared-services subnet prefix that workloads are allowed to reach through the hub peering.')
param hubSharedServicesPrefix string

@description('Hub private-endpoints subnet prefix that workloads are allowed to reach through the hub peering.')
param hubPrivateEndpointsPrefix string

@description('Future spoke supernet reserved by the landing zone for all workload spokes.')
param futureSpokeSupernet string

@description('Point-to-Site VPN client pool used for break-glass operator reachability.')
param vpnClientAddressPool string

var workloadSubnetName = take('snet-${spokeToken}-workload', 80)
var privateEndpointsSubnetName = take('snet-${spokeToken}-private-endpoints', 80)
var workloadSubnetPrefixes = [
  subnetPrefixes.workload
  subnetPrefixes.privateEndpoints
]

resource workloadNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-${workloadSubnetName}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowIntraSpokeInbound'
        properties: {
          description: 'Allows traffic that stays inside the workload spoke boundary.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefixes: addressPrefixes
          destinationAddressPrefix: subnetPrefixes.workload
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowOperatorP2SInbound'
        properties: {
          description: 'Allows approved break-glass operators to reach the workload subnet through the hub gateway.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: vpnClientAddressPool
          destinationAddressPrefix: subnetPrefixes.workload
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyHubPlatformInbound'
        properties: {
          description: 'Prevents hub platform and runner subnets from initiating traffic into the workload subnet.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefixes: hubAddressPrefixes
          destinationAddressPrefix: subnetPrefixes.workload
          access: 'Deny'
          priority: 3000
          direction: 'Inbound'
        }
      }
      {
        name: 'DenySpokeSupernetInbound'
        properties: {
          description: 'Blocks lateral traffic from other spokes that share the reserved spoke supernet.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: futureSpokeSupernet
          destinationAddressPrefix: subnetPrefixes.workload
          access: 'Deny'
          priority: 3100
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyInternetInbound'
        properties: {
          description: 'Keeps the workload subnet private by default.'
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
      {
        name: 'AllowIntraSpokeOutbound'
        properties: {
          description: 'Allows traffic that stays inside the workload spoke boundary.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: subnetPrefixes.workload
          destinationAddressPrefixes: workloadSubnetPrefixes
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowHubSharedServicesOutbound'
        properties: {
          description: 'Allows workloads to reach approved shared services hosted in the hub.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: subnetPrefixes.workload
          destinationAddressPrefix: hubSharedServicesPrefix
          access: 'Allow'
          priority: 200
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowHubPrivateEndpointsOutbound'
        properties: {
          description: 'Allows workloads to consume hub-hosted private endpoints such as the shared registry path.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: subnetPrefixes.workload
          destinationAddressPrefix: hubPrivateEndpointsPrefix
          access: 'Allow'
          priority: 210
          direction: 'Outbound'
        }
      }
      {
        name: 'DenyHubPlatformOutbound'
        properties: {
          description: 'Prevents workloads from reaching non-approved hub subnets over the peering.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: subnetPrefixes.workload
          destinationAddressPrefixes: hubAddressPrefixes
          access: 'Deny'
          priority: 3000
          direction: 'Outbound'
        }
      }
      {
        name: 'DenySpokeSupernetOutbound'
        properties: {
          description: 'Blocks lateral traffic from the workload subnet to other spokes.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: subnetPrefixes.workload
          destinationAddressPrefix: futureSpokeSupernet
          access: 'Deny'
          priority: 3100
          direction: 'Outbound'
        }
      }
    ]
  }
}

resource privateEndpointsNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-${privateEndpointsSubnetName}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowWorkloadInbound'
        properties: {
          description: 'Allows workload resources inside the same spoke to consume local private endpoints.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: subnetPrefixes.workload
          destinationAddressPrefix: subnetPrefixes.privateEndpoints
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowOperatorP2SInbound'
        properties: {
          description: 'Allows approved break-glass operators to reach spoke private endpoints for diagnostics.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: vpnClientAddressPool
          destinationAddressPrefix: subnetPrefixes.privateEndpoints
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyHubPlatformInbound'
        properties: {
          description: 'Prevents hub platform and runner subnets from initiating traffic into the private-endpoints subnet.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefixes: hubAddressPrefixes
          destinationAddressPrefix: subnetPrefixes.privateEndpoints
          access: 'Deny'
          priority: 3000
          direction: 'Inbound'
        }
      }
      {
        name: 'DenySpokeSupernetInbound'
        properties: {
          description: 'Blocks lateral traffic from other spokes that share the reserved spoke supernet.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: futureSpokeSupernet
          destinationAddressPrefix: subnetPrefixes.privateEndpoints
          access: 'Deny'
          priority: 3100
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyInternetInbound'
        properties: {
          description: 'Keeps the spoke private-endpoints subnet private by default.'
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
      {
        name: 'AllowIntraSpokeOutbound'
        properties: {
          description: 'Allows the private-endpoints subnet to return traffic only inside the local spoke boundary.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: subnetPrefixes.privateEndpoints
          destinationAddressPrefixes: workloadSubnetPrefixes
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      {
        name: 'DenyHubPlatformOutbound'
        properties: {
          description: 'Prevents private endpoints from becoming a pivot into the wider hub platform network.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: subnetPrefixes.privateEndpoints
          destinationAddressPrefixes: hubAddressPrefixes
          access: 'Deny'
          priority: 3000
          direction: 'Outbound'
        }
      }
      {
        name: 'DenySpokeSupernetOutbound'
        properties: {
          description: 'Blocks lateral traffic from the private-endpoints subnet to other spokes.'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: subnetPrefixes.privateEndpoints
          destinationAddressPrefix: futureSpokeSupernet
          access: 'Deny'
          priority: 3100
          direction: 'Outbound'
        }
      }
    ]
  }
}

resource workloadRouteTable 'Microsoft.Network/routeTables@2024-05-01' = {
  name: 'rt-${workloadSubnetName}'
  location: location
  tags: tags
  properties: {
    disableBgpRoutePropagation: false
    routes: []
  }
}

resource privateEndpointsRouteTable 'Microsoft.Network/routeTables@2024-05-01' = {
  name: 'rt-${privateEndpointsSubnetName}'
  location: location
  tags: tags
  properties: {
    disableBgpRoutePropagation: false
    routes: []
  }
}

resource spokeVnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
    subnets: [
      {
        name: workloadSubnetName
        properties: {
          addressPrefix: subnetPrefixes.workload
          networkSecurityGroup: {
            id: workloadNsg.id
          }
          routeTable: {
            id: workloadRouteTable.id
          }
        }
      }
      {
        name: privateEndpointsSubnetName
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
    ]
  }
}

output spoke object = {
  name: spokeName
  resourceGroupName: resourceGroup().name
  vnetName: spokeVnet.name
  vnetId: spokeVnet.id
  subnetNames: {
    workload: workloadSubnetName
    privateEndpoints: privateEndpointsSubnetName
  }
  subnetIds: {
    workload: resourceId('Microsoft.Network/virtualNetworks/subnets', spokeVnet.name, workloadSubnetName)
    privateEndpoints: resourceId('Microsoft.Network/virtualNetworks/subnets', spokeVnet.name, privateEndpointsSubnetName)
  }
  routeTables: {
    workload: workloadRouteTable.id
    privateEndpoints: privateEndpointsRouteTable.id
  }
  networkSecurityGroups: {
    workload: workloadNsg.id
    privateEndpoints: privateEndpointsNsg.id
  }
  addressPlan: {
    vnetPrefixes: addressPrefixes
    subnetPrefixes: subnetPrefixes
    constraints: [
      'Allocate workload spoke prefixes from the reserved future spoke supernet ${futureSpokeSupernet}.'
      'Do not overlap workload spokes with hub prefixes ${join(hubAddressPrefixes, ', ')} or with other spokes.'
      'Reserve the declared future prefix ${subnetPrefixes.reservedFuture} for later in-spoke growth so workloads do not need renumbering.'
    ]
  }
  trafficModel: {
    allowedInbound: [
      'Break-glass operators from ${vpnClientAddressPool} may reach workload and private-endpoint subnets.'
      'Traffic that stays inside the local spoke address space remains allowed.'
    ]
    allowedOutbound: [
      'Workloads can reach the hub shared-services subnet ${hubSharedServicesPrefix}.'
      'Workloads can reach the hub private-endpoints subnet ${hubPrivateEndpointsPrefix}.'
      'Private-endpoint resources return traffic only inside the same spoke.'
    ]
    blockedByDefault: [
      'Hub platform subnets other than approved shared-services and private-endpoints prefixes are denied.'
      'Spoke-to-spoke traffic across the reserved supernet ${futureSpokeSupernet} is denied at the subnet boundary.'
      'Internet-originated inbound traffic remains denied by default.'
    ]
  }
}
