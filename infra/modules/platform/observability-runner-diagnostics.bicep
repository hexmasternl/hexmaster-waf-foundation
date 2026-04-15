targetScope = 'resourceGroup'

@description('Workspace resource ID used by the diagnostic settings.')
param workspaceId string

@description('Minimal observability baseline configuration.')
param observabilityConfig object = {
  enabled: true
  logAnalyticsDestinationType: 'Dedicated'
}

@description('Runner resources that should send diagnostics to the shared workspace.')
param runnerDiagnostics object

var diagnosticSettingName = 'send-to-log-analytics'

resource runnerFunctionApp 'Microsoft.Web/sites@2024-11-01' existing = {
  name: runnerDiagnostics.functionAppName
}

#disable-next-line use-recent-api-versions
resource runnerFunctionAppDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (observabilityConfig.enabled) {
  name: diagnosticSettingName
  scope: runnerFunctionApp
  properties: {
    workspaceId: workspaceId
    logAnalyticsDestinationType: observabilityConfig.logAnalyticsDestinationType
    logs: [
      {
        categoryGroup: 'allLogs'
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

resource runnerVmScaleSet 'Microsoft.Compute/virtualMachineScaleSets@2024-11-01' existing = {
  name: runnerDiagnostics.vmScaleSetName
}

#disable-next-line use-recent-api-versions
resource runnerVmScaleSetDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (observabilityConfig.enabled) {
  name: diagnosticSettingName
  scope: runnerVmScaleSet
  properties: {
    workspaceId: workspaceId
    logAnalyticsDestinationType: observabilityConfig.logAnalyticsDestinationType
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource autoscalerStorageAccount 'Microsoft.Storage/storageAccounts@2025-01-01' existing = {
  name: runnerDiagnostics.autoscalerStorageAccountName
}

#disable-next-line use-recent-api-versions
resource autoscalerStorageAccountDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (observabilityConfig.enabled) {
  name: diagnosticSettingName
  scope: autoscalerStorageAccount
  properties: {
    workspaceId: workspaceId
    logAnalyticsDestinationType: observabilityConfig.logAnalyticsDestinationType
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource autoscalerStorageBlobService 'Microsoft.Storage/storageAccounts/blobServices@2025-01-01' existing = {
  parent: autoscalerStorageAccount
  name: 'default'
}

#disable-next-line use-recent-api-versions
resource autoscalerStorageBlobDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (observabilityConfig.enabled) {
  name: diagnosticSettingName
  scope: autoscalerStorageBlobService
  properties: {
    workspaceId: workspaceId
    logAnalyticsDestinationType: observabilityConfig.logAnalyticsDestinationType
    logs: [
      {
        categoryGroup: 'allLogs'
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

resource autoscalerStorageFileService 'Microsoft.Storage/storageAccounts/fileServices@2025-01-01' existing = {
  parent: autoscalerStorageAccount
  name: 'default'
}

#disable-next-line use-recent-api-versions
resource autoscalerStorageFileDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (observabilityConfig.enabled) {
  name: diagnosticSettingName
  scope: autoscalerStorageFileService
  properties: {
    workspaceId: workspaceId
    logAnalyticsDestinationType: observabilityConfig.logAnalyticsDestinationType
    logs: [
      {
        categoryGroup: 'allLogs'
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

resource autoscalerStorageQueueService 'Microsoft.Storage/storageAccounts/queueServices@2025-01-01' existing = {
  parent: autoscalerStorageAccount
  name: 'default'
}

#disable-next-line use-recent-api-versions
resource autoscalerStorageQueueDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (observabilityConfig.enabled) {
  name: diagnosticSettingName
  scope: autoscalerStorageQueueService
  properties: {
    workspaceId: workspaceId
    logAnalyticsDestinationType: observabilityConfig.logAnalyticsDestinationType
    logs: [
      {
        categoryGroup: 'allLogs'
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

resource autoscalerStorageTableService 'Microsoft.Storage/storageAccounts/tableServices@2025-01-01' existing = {
  parent: autoscalerStorageAccount
  name: 'default'
}

#disable-next-line use-recent-api-versions
resource autoscalerStorageTableDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (observabilityConfig.enabled) {
  name: diagnosticSettingName
  scope: autoscalerStorageTableService
  properties: {
    workspaceId: workspaceId
    logAnalyticsDestinationType: observabilityConfig.logAnalyticsDestinationType
    logs: [
      {
        categoryGroup: 'allLogs'
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
