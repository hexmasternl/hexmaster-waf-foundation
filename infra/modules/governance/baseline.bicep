targetScope = 'subscription'

@description('Azure region used for naming conventions and governance metadata.')
param primaryLocation string

@description('Short landing-zone identifier used in names and tags.')
param landingZoneName string

@description('Environment stamp for the landing zone.')
param environment string

@description('Owning team or platform contact.')
param platformOwner string

@description('Cost center, cost code, or internal chargeback reference.')
param platformCostCenter string

@description('Additional tags merged into the shared governance baseline.')
param tags object = {}

@description('Existing Log Analytics workspace resource ID used for diagnostics defaults.')
param diagnosticsWorkspaceResourceId string = ''

@description('Monthly subscription budget amount.')
param budgetAmount int

@description('Budget period start date in ISO 8601 format.')
param budgetStartDate string

@description('Email recipients for budget threshold notifications.')
param budgetContactEmails array

var locationToken = toLower(replace(primaryLocation, ' ', ''))
var landingZoneToken = toLower(replace(landingZoneName, '-', ''))
var prefix = '${landingZoneName}-${environment}'
var naming = {
  prefix: prefix
  resourceGroups: {
    management: 'rg-${prefix}-management-${locationToken}'
    connectivity: 'rg-${prefix}-connectivity-${locationToken}'
    platform: 'rg-${prefix}-platform-${locationToken}'
  }
  resources: {
    logAnalyticsWorkspace: 'log-${prefix}-${locationToken}'
    hubVirtualNetwork: 'vnet-${prefix}-hub-${locationToken}'
    sharedServicesSubnet: 'snet-${prefix}-shared-services'
    privateEndpointsSubnet: 'snet-${prefix}-private-endpoints'
    runnerInfrastructureSubnet: 'snet-${prefix}-runners'
    vpnGatewayPublicIp: 'pip-${prefix}-vpn-${locationToken}'
    vpnGateway: 'vpngw-${prefix}-${locationToken}'
    containerAppsEnvironment: 'cae-${prefix}-${locationToken}'
    containerRegistry: take('acr${landingZoneToken}${environment}${take(locationToken, 6)}', 50)
    platformKeyVault: take('kv-${prefix}-${locationToken}', 24)
    runnerJob: 'job-${prefix}-github'
    runnerExecutionIdentity: 'id-${prefix}-runner-exec'
    runnerRegistryIdentity: 'id-${prefix}-runner-reg'
  }
}

var requiredTags = union({
  'alz:landingZone': landingZoneName
  'alz:environment': environment
  'alz:owner': platformOwner
  'alz:costCenter': platformCostCenter
  'alz:lifecycle': 'shared-platform'
  'alz:managedBy': 'bicep'
}, tags)

var diagnosticsDefaults = {
  enabled: !empty(diagnosticsWorkspaceResourceId)
  workspaceResourceId: diagnosticsWorkspaceResourceId
  destinationType: 'Dedicated'
  logCategoryGroups: [
    'allLogs'
    'audit'
  ]
  metricCategories: [
    'AllMetrics'
  ]
  retentionInDays: 30
  notes: 'Apply this baseline to supported platform resources when their modules are introduced.'
}

var allowedServiceTiers = {
  networking: {
    topology: 'HubAndSpoke'
    vpnGatewaySku: 'VpnGw1'
    pointToSiteOnly: true
    bastionDefault: 'NotEnabled'
    azureFirewallDefault: 'NotEnabled'
    natGatewayDefault: 'NotEnabled'
    virtualWanDefault: 'NotEnabled'
  }
  registry: {
    service: 'Azure Container Registry'
    sku: 'Premium'
    adminUserEnabled: false
    publicNetworkAccess: 'Disabled'
    privateEndpointConnectivity: 'Required'
    authenticationAsArm: 'Enabled'
    premiumJustification: 'Private Link requires Premium and is the accepted cost exception for the central shared registry.'
  }
  runnerPlatform: {
    service: 'Azure Container Apps Jobs'
    environmentProfile: 'Consumption'
    minExecutions: 0
    dedicatedWorkloadProfiles: 'NotAllowedByDefault'
    imageSource: 'CentralACR'
    ingressExposure: 'InternalOnly'
    secretSource: 'SharedKeyVault'
  }
}

var costGuardrails = {
  monthlyBudgetAmount: budgetAmount
  exceptionApprovalRequiredFor: [
    'Azure Bastion'
    'Azure Firewall'
    'Azure NAT Gateway'
    'Azure Virtual WAN'
    'Azure Container Apps dedicated workload profiles'
  ]
  reviewNotes: [
    'Keep shared platform services in the hub and onboard workload services to spokes later.'
    'Prefer consumption-based or entry-level SKUs until production workload evidence justifies higher spend.'
    'Use Azure Container Registry Premium for the single shared registry because Private Link is part of the baseline private connectivity posture.'
    'Enable diagnostics only after routing to an existing workspace to avoid orphaned ingestion cost.'
  ]
}

module subscriptionBudget './budget.bicep' = {
  name: 'subscription-budget'
  params: {
    budgetName: 'budget-${prefix}'
    amount: budgetAmount
    startDate: budgetStartDate
    contactEmails: budgetContactEmails
  }
}

output requiredTags object = requiredTags
output diagnosticsDefaults object = diagnosticsDefaults
output allowedServiceTiers object = allowedServiceTiers
output baseline object = {
  subscriptionScope: {
    subscriptionId: subscription().subscriptionId
    tenantId: subscription().tenantId
    deploymentScope: 'Subscription'
    managementGroupAlignment: 'Attach the subscription to the platform landing-zone management group before onboarding workloads.'
  }
  naming: naming
  tags: requiredTags
  diagnostics: diagnosticsDefaults
  allowedServiceTiers: allowedServiceTiers
  costGuardrails: costGuardrails
  budget: subscriptionBudget.outputs.summary
}
