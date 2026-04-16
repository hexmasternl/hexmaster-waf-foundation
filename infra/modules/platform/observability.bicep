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
  runnerVmssGuestTelemetry: {
    enabled: true
  }
}

@description('Name of the shared platform Key Vault.')
param keyVaultName string

var observabilityEnabled = observabilityConfig.enabled
var diagnosticSettingName = 'send-to-log-analytics'
var runnerVmssGuestTelemetryEnabled = observabilityEnabled && (observabilityConfig.?runnerVmssGuestTelemetry.?enabled ?? true)
var runnerVmssGuestTelemetryRuleName = take('dcr-${workspaceName}-runner-linux', 64)
var runnerVmssGuestTelemetryDestinationName = 'runner-linux-workspace'

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

resource runnerVmssGuestTelemetryRule 'Microsoft.Insights/dataCollectionRules@2024-03-11' = if (runnerVmssGuestTelemetryEnabled) {
  name: runnerVmssGuestTelemetryRuleName
  location: location
  kind: 'Linux'
  tags: tags
  properties: {
    description: 'Collect Linux guest logs and telemetry for the GitHub runner VM scale set.'
    dataSources: {
      performanceCounters: [
        {
          name: 'runnerVmssDetailedMetrics'
          streams: [
            'Microsoft-InsightsMetrics'
          ]
          samplingFrequencyInSeconds: 60
          counterSpecifiers: [
            '\\VmInsights\\DetailedMetrics'
          ]
        }
      ]
      syslog: [
        {
          name: 'runnerVmssSyslogAuth'
          streams: [
            'Microsoft-Syslog'
          ]
          facilityNames: [
            'auth'
            'authpriv'
          ]
          logLevels: [
            'Warning'
            'Error'
            'Critical'
            'Alert'
            'Emergency'
          ]
        }
        {
          name: 'runnerVmssSyslogDaemon'
          streams: [
            'Microsoft-Syslog'
          ]
          facilityNames: [
            'daemon'
            'syslog'
          ]
          logLevels: [
            'Info'
            'Notice'
            'Warning'
            'Error'
            'Critical'
            'Alert'
            'Emergency'
          ]
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          name: runnerVmssGuestTelemetryDestinationName
          workspaceResourceId: workspace.id
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Microsoft-InsightsMetrics'
          'Microsoft-Syslog'
        ]
        destinations: [
          runnerVmssGuestTelemetryDestinationName
        ]
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

output runnerVmssGuestTelemetry object = {
  enabled: runnerVmssGuestTelemetryEnabled
  dataCollectionRuleName: runnerVmssGuestTelemetryEnabled ? runnerVmssGuestTelemetryRule.name : ''
  dataCollectionRuleId: runnerVmssGuestTelemetryEnabled ? runnerVmssGuestTelemetryRule.id : ''
}
