targetScope = 'resourceGroup'

@description('Principal ID of the user-assigned managed identity that needs Monitoring Metrics Publisher on the data collection rule.')
param principalId string

@description('Name of the data collection rule in this resource group.')
param dataCollectionRuleName string

var monitoringMetricsPublisherRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '3913510d-42f4-4e42-8a64-420c390055eb'
)

resource dataCollectionRule 'Microsoft.Insights/dataCollectionRules@2024-03-11' existing = {
  name: dataCollectionRuleName
}

resource amaRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(dataCollectionRule.id, principalId, monitoringMetricsPublisherRoleDefinitionId)
  scope: dataCollectionRule
  properties: {
    roleDefinitionId: monitoringMetricsPublisherRoleDefinitionId
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
