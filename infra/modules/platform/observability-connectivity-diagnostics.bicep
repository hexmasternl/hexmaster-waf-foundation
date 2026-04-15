targetScope = 'resourceGroup'

@description('Workspace resource ID used by the diagnostic settings.')
param workspaceId string

@description('Minimal observability baseline configuration.')
param observabilityConfig object = {
  enabled: true
  logAnalyticsDestinationType: 'Dedicated'
}

@description('Name of the Point-to-Site VPN virtual network gateway.')
param virtualNetworkGatewayName string

var diagnosticSettingName = 'send-to-log-analytics'

resource virtualNetworkGateway 'Microsoft.Network/virtualNetworkGateways@2024-05-01' existing = {
  name: virtualNetworkGatewayName
}

#disable-next-line use-recent-api-versions
resource virtualNetworkGatewayDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (observabilityConfig.enabled) {
  name: diagnosticSettingName
  scope: virtualNetworkGateway
  properties: {
    workspaceId: workspaceId
    logAnalyticsDestinationType: observabilityConfig.logAnalyticsDestinationType
    logs: [
      {
        category: 'GatewayDiagnosticLog'
        enabled: true
      }
      {
        category: 'IKEDiagnosticLog'
        enabled: true
      }
      {
        category: 'P2SDiagnosticLog'
        enabled: true
      }
      {
        category: 'RouteDiagnosticLog'
        enabled: true
      }
      {
        category: 'TunnelDiagnosticLog'
        enabled: true
      }
    ]
  }
}
