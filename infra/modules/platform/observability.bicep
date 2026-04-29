targetScope = 'resourceGroup'

@description('Azure region for the shared Log Analytics workspace and Application Insights.')
param location string

@description('Tags applied to the observability resources.')
param tags object = {}

@description('Name of the shared Log Analytics workspace.')
param workspaceName string

@description('Name of the Application Insights component.')
param applicationInsightsName string

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

var observabilityEnabled = observabilityConfig.enabled
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

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = if (observabilityEnabled) {
  name: applicationInsightsName
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspace.id
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    DisableLocalAuth: false
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
          // Captures runner service (daemon), GitHub Actions output (syslog/user), cron activity
          name: 'runnerVmssSyslogSystem'
          streams: [
            'Microsoft-Syslog'
          ]
          facilityNames: [
            'daemon'
            'syslog'
            'user'
            'cron'
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
        {
          name: 'runnerVmssSyslogKernel'
          streams: [
            'Microsoft-Syslog'
          ]
          facilityNames: [
            'kern'
          ]
          logLevels: [
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

output applicationInsights object = {
  enabled: observabilityEnabled
  name: observabilityEnabled ? applicationInsights.name : ''
  id: observabilityEnabled ? applicationInsights.id : ''
  connectionString: observabilityEnabled ? applicationInsights.properties.ConnectionString : ''
  instrumentationKey: observabilityEnabled ? applicationInsights.properties.InstrumentationKey : ''
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
