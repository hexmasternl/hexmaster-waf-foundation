targetScope = 'resourceGroup'

@description('Workspace resource ID used by the diagnostic settings.')
param workspaceId string

@description('Minimal observability baseline configuration.')
param observabilityConfig object = {
  enabled: true
  logAnalyticsDestinationType: 'Dedicated'
}

@description('Name of the shared platform Key Vault.')
param keyVaultName string

var diagnosticSettingName = 'send-to-log-analytics'

resource keyVault 'Microsoft.KeyVault/vaults@2024-11-01' existing = {
  name: keyVaultName
}

#disable-next-line use-recent-api-versions
resource keyVaultDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (observabilityConfig.enabled) {
  name: diagnosticSettingName
  scope: keyVault
  properties: {
    workspaceId: workspaceId
    logAnalyticsDestinationType: observabilityConfig.logAnalyticsDestinationType
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}
