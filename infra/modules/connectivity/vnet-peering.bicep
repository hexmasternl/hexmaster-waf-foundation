targetScope = 'resourceGroup'

@description('Name of the local VNet where the peering is created.')
param localVnetName string

@description('Name of the peering resource on the local VNet.')
param peeringName string

@description('Remote VNet resource ID.')
param remoteVnetId string

@description('Whether virtual network access is enabled across the peering.')
param allowVirtualNetworkAccess bool = true

@description('Whether forwarded traffic is allowed across the peering.')
param allowForwardedTraffic bool = false

@description('Whether the local VNet shares its gateway with the remote VNet.')
param allowGatewayTransit bool = false

@description('Whether the local VNet uses the remote gateway.')
param useRemoteGateways bool = false

resource localVnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: localVnetName
}

resource peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  name: peeringName
  parent: localVnet
  properties: {
    allowVirtualNetworkAccess: allowVirtualNetworkAccess
    allowForwardedTraffic: allowForwardedTraffic
    allowGatewayTransit: allowGatewayTransit
    useRemoteGateways: useRemoteGateways
    remoteVirtualNetwork: {
      id: remoteVnetId
    }
  }
}

output peering object = {
  name: peering.name
  id: peering.id
  localVnetName: localVnet.name
  remoteVnetId: remoteVnetId
  allowVirtualNetworkAccess: allowVirtualNetworkAccess
  allowForwardedTraffic: allowForwardedTraffic
  allowGatewayTransit: allowGatewayTransit
  useRemoteGateways: useRemoteGateways
}
