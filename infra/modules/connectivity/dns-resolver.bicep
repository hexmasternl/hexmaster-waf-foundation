targetScope = 'resourceGroup'

@description('Azure region for the DNS resolver.')
param location string

@description('Tags applied to the DNS resolver resources.')
param tags object = {}

@description('Name of the DNS Private Resolver.')
param resolverName string

@description('Resource ID of the hub virtual network the resolver is associated with.')
param hubVnetId string

@description('Resource ID of the inbound endpoint subnet (must be delegated to Microsoft.Network/dnsResolvers).')
param inboundSubnetId string

@description('Resource ID of the outbound endpoint subnet (must be delegated to Microsoft.Network/dnsResolvers).')
param outboundSubnetId string

@description('Static private IP address allocated to the inbound endpoint. Must be within the inbound subnet range.')
param inboundIpAddress string = '10.20.3.4'

resource dnsResolver 'Microsoft.Network/dnsResolvers@2025-10-01-preview' = {
  name: resolverName
  location: location
  tags: tags
  properties: {
    virtualNetwork: {
      id: hubVnetId
    }
  }
}

resource inboundEndpoint 'Microsoft.Network/dnsResolvers/inboundEndpoints@2025-10-01-preview' = {
  name: 'inbound'
  location: location
  tags: tags
  parent: dnsResolver
  properties: {
    ipConfigurations: [
      {
        subnet: {
          id: inboundSubnetId
        }
        privateIpAllocationMethod: 'Static'
        privateIpAddress: inboundIpAddress
      }
    ]
  }
}

resource outboundEndpoint 'Microsoft.Network/dnsResolvers/outboundEndpoints@2025-10-01-preview' = {
  name: 'outbound'
  location: location
  tags: tags
  parent: dnsResolver
  properties: {
    subnet: {
      id: outboundSubnetId
    }
  }
}

output resolver object = {
  id: dnsResolver.id
  name: dnsResolver.name
  inboundEndpoint: {
    id: inboundEndpoint.id
    name: inboundEndpoint.name
    ipAddress: inboundIpAddress
  }
  outboundEndpoint: {
    id: outboundEndpoint.id
    name: outboundEndpoint.name
  }
  operatorNotes: [
    'Hub VNet DHCP DNS is set to ${inboundIpAddress} — all hub VMs resolve via this endpoint.'
    'Spoke VMs using hub DNS zones will resolve via this endpoint through VNet peering.'
    'VPN P2S clients must configure their DNS server to ${inboundIpAddress} after connecting to resolve private hostnames.'
    'The outbound endpoint is ready for DNS forwarding rulesets to on-premises resolvers when required.'
    'The resolver forwards all other queries to Azure DNS (168.63.129.16) by default — no additional forwarding rules needed for standard Azure private DNS zones.'
  ]
}
