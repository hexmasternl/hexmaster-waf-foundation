targetScope = 'resourceGroup'

@description('Azure region for the shared Log Analytics workspace.')
param location string

@description('Tags applied to the observability resources.')
param tags object = {}

@description('Name of the shared Log Analytics workspace.')
param workspaceName string

@description('Minimal observability baseline configuration.')
param observabilityConfig object = {
  enabled: true
  workspaceSku: 'PerGB2018'
  retentionInDays: 30
  dailyQuotaGb: 1
  logAnalyticsDestinationType: 'Dedicated'
}

@description('Name of the shared platform Key Vault.')
param keyVaultName string

var observabilityEnabled = observabilityConfig.enabled
var diagnosticSettingName = 'send-to-log-analytics'

resource workspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' = if (observabilityEnabled) {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: observabilityConfig.workspaceSku
    }
    retentionInDays: observabilityConfig.retentionInDays
    workspaceCapping: {
      dailyQuotaGb: observabilityConfig.dailyQuotaGb
    }
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2024-11-01' existing = {
  name: keyVaultName
}

#disable-next-line use-recent-api-versions
resource keyVaultDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (observabilityEnabled) {
  name: diagnosticSettingName
  scope: keyVault
  properties: {
    workspaceId: workspace.id
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

output workspace object = {
  enabled: observabilityEnabled
  name: observabilityEnabled ? workspace.name : ''
  id: observabilityEnabled ? workspace.id : ''
  resourceGroupName: observabilityEnabled ? resourceGroup().name : ''
}

output lowCostDefaults object = {
  sku: observabilityEnabled ? observabilityConfig.workspaceSku : ''
  retentionInDays: observabilityEnabled ? observabilityConfig.retentionInDays : 0
  dailyQuotaGb: observabilityEnabled ? observabilityConfig.dailyQuotaGb : 0
  logAnalyticsDestinationType: observabilityEnabled ? observabilityConfig.logAnalyticsDestinationType : ''
}
