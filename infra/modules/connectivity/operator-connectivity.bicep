targetScope = 'resourceGroup'

@description('Azure region for the operator connectivity resources.')
param location string

@description('Tags applied to operator connectivity resources.')
param tags object = {}

@description('Name of the public IP used by the VPN gateway.')
param gatewayPublicIpName string

@description('Name of the Point-to-Site virtual network gateway.')
param virtualNetworkGatewayName string

@description('Gateway subnet resource ID from the hub VNet.')
param gatewaySubnetId string

@description('Low-cost VPN gateway SKU for Point-to-Site access.')
param vpnGatewaySku string = 'VpnGw1'

@description('Address pool assigned to Point-to-Site VPN clients.')
param vpnClientAddressPool string

@description('Microsoft Entra tenant ID used for Point-to-Site VPN authentication.')
param entraTenantId string

@description('Microsoft-registered Azure VPN Client audience ID.')
param entraAudience string = 'c632b3df-fb67-4d84-bdcf-b95ad541b5c8'

@description('Break-glass operating model metadata emitted as deployment outputs.')
param breakGlass object

#disable-next-line no-hardcoded-env-urls
var entraTenantUri = 'https://login.microsoftonline.com/${entraTenantId}'
#disable-next-line no-hardcoded-env-urls
var entraIssuerUri = 'https://sts.windows.net/${entraTenantId}/'

resource gatewayPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: gatewayPublicIpName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource virtualNetworkGateway 'Microsoft.Network/virtualNetworkGateways@2024-05-01' = {
  name: virtualNetworkGatewayName
  location: location
  tags: tags
  properties: {
    activeActive: false
    enableBgp: false
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    sku: {
      name: vpnGatewaySku
      tier: vpnGatewaySku
    }
    ipConfigurations: [
      {
        name: 'default'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: gatewayPublicIp.id
          }
          subnet: {
            id: gatewaySubnetId
          }
        }
      }
    ]
    vpnClientConfiguration: {
      aadTenant: entraTenantUri
      aadAudience: entraAudience
      aadIssuer: entraIssuerUri
      vpnAuthenticationTypes: [
        'AAD'
      ]
      vpnClientAddressPool: {
        addressPrefixes: [
          vpnClientAddressPool
        ]
      }
      vpnClientProtocols: [
        'OpenVPN'
      ]
    }
  }
}

output connectivity object = {
  publicIpResourceId: gatewayPublicIp.id
  virtualNetworkGatewayId: virtualNetworkGateway.id
  pointToSite: {
    authentication: 'Microsoft Entra ID'
    client: breakGlass.primaryClient
    protocols: [
      'OpenVPN'
    ]
    gatewaySku: vpnGatewaySku
    clientAddressPool: vpnClientAddressPool
    tenant: entraTenantUri
    audience: entraAudience
    issuer: entraIssuerUri
    reachabilityNotes: [
      'P2S VPN is the primary low-cost operator access path into the platform hub.'
      'Operators connect with Azure VPN Client and receive an address from the dedicated VPN client pool.'
      'Spokes that need break-glass access must consume the hub gateway through VNet peering with gateway transit enabled.'
    ]
  }
  breakGlass: {
    primaryClient: breakGlass.primaryClient
    authenticationMode: breakGlass.authenticationMode
    operatorGroupName: breakGlass.operatorGroupName
    emergencyAccessGroupName: breakGlass.emergencyAccessGroupName
    allowedTargetSubnets: breakGlass.allowedTargetSubnets
    spokeReachabilityRequirement: breakGlass.spokeReachabilityRequirement
    operatingModel: [
      'Use just-in-time group membership for day-to-day operators and keep emergency accounts separate from routine administration.'
      'Test VPN profile download and emergency access at least quarterly.'
      'Limit the break-glass path to hub platform resources and approved spokes; keep workloads outside the hub.'
    ]
  }
}
