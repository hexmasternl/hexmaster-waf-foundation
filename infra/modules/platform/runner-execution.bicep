targetScope = 'resourceGroup'

@description('Azure region for the runner execution platform.')
param location string

@description('Tags applied to runner platform resources.')
param tags object = {}

@description('Name of the GitHub Actions runner VM scale set.')
param runnerScaleSetName string

@description('Name of the runner execution identity used by the VM scale set.')
param runnerExecutionIdentityName string

@description('Name of the autoscaler Function App.')
param runnerAutoscalerFunctionAppName string

@description('Name of the existing shared platform Key Vault.')
param keyVaultName string

@description('Resource group containing the shared platform Key Vault.')
param keyVaultResourceGroupName string

@description('Subnet resource ID used by the runner VM scale set.')
param infrastructureSubnetId string

@description('Runner execution configuration for the VM scale set and webhook autoscaler.')
param runnerExecutionConfig object = {
  deployRunnerPool: false
  githubUrl: 'https://github.com/hexmasternl'
  owner: 'hexmasternl'
  repositories: [
    'hexmaster-waf-foundation'
  ]
  runnerLabels: [
    'vmss'
  ]
  runnerGroup: 'HexMaster Landingzone'
  runnerVersion: '2.333.1'
  vmSku: 'Standard_D2as_v5'
  osDiskSizeGb: 64
  adminUsername: 'runneradmin'
  adminPublicKey: ''
  minRunners: 0
  maxRunners: 10
  githubPatSecretName: 'github-actions-pat'
  githubWebhookSecretName: 'github-webhook-secret'
  registrationTokenApiUrl: 'https://api.github.com/orgs/hexmasternl/actions/runners/registration-token'
}

var virtualMachineContributorRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '9980e02c-c2be-4d73-94e8-173b1dc7cf3c')
var deployRunnerPool = runnerExecutionConfig.deployRunnerPool && !empty(runnerExecutionConfig.adminPublicKey)
var functionPlanName = 'plan-${take(replace(runnerAutoscalerFunctionAppName, '_', '-'), 36)}'
var storageAccountName = toLower(take('st${uniqueString(resourceGroup().id, runnerAutoscalerFunctionAppName)}', 24))
var patSecretUri = '${platformKeyVault.properties.vaultUri}secrets/${runnerExecutionConfig.githubPatSecretName}'
var webhookSecretUri = '${platformKeyVault.properties.vaultUri}secrets/${runnerExecutionConfig.githubWebhookSecretName}'
var targetRepositories = [for repository in runnerExecutionConfig.repositories: '${runnerExecutionConfig.owner}/${repository}']
var targetRepositoriesCsv = join(targetRepositories, ',')
var autoscalerStorageConnectionString = deployRunnerPool ? 'DefaultEndpointsProtocol=https;AccountName=${autoscalerStorage!.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${autoscalerStorage!.listKeys().keys[0].value}' : ''
var cloudInitTemplate = loadTextContent('../../runner-vmss/cloud-init.yml')
var cloudInit = replace(
  replace(
    replace(
      replace(
        replace(
          replace(
            replace(
              replace(cloudInitTemplate, '__RUNNER_VERSION__', runnerExecutionConfig.runnerVersion),
              '__GITHUB_URL__',
              runnerExecutionConfig.githubUrl),
            '__RUNNER_GROUP__',
            runnerExecutionConfig.runnerGroup),
          '__RUNNER_LABELS__',
          join(runnerExecutionConfig.runnerLabels, ',')),
        '__KEY_VAULT_URI__',
        platformKeyVault.properties.vaultUri),
      '__GITHUB_PAT_SECRET_NAME__',
      runnerExecutionConfig.githubPatSecretName),
    '__REGISTRATION_TOKEN_API_URL__',
    runnerExecutionConfig.registrationTokenApiUrl),
  '__MANAGED_IDENTITY_CLIENT_ID__',
  deployRunnerPool ? runnerExecutionIdentity!.properties.clientId : '')

resource platformKeyVault 'Microsoft.KeyVault/vaults@2024-11-01' existing = {
  name: keyVaultName
  scope: resourceGroup(subscription().subscriptionId, keyVaultResourceGroupName)
}

resource runnerExecutionIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = if (deployRunnerPool) {
  name: runnerExecutionIdentityName
  location: location
  tags: tags
}

resource runnerVmss 'Microsoft.Compute/virtualMachineScaleSets@2024-11-01' = if (deployRunnerPool) {
  name: runnerScaleSetName
  location: location
  tags: tags
  sku: {
    name: runnerExecutionConfig.vmSku
    tier: 'Standard'
    capacity: runnerExecutionConfig.minRunners
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${runnerExecutionIdentity.id}': {}
    }
  }
  properties: {
    overprovision: false
    upgradePolicy: {
      mode: 'Manual'
    }
    virtualMachineProfile: {
      storageProfile: {
        imageReference: {
          publisher: 'Canonical'
          offer: '0001-com-ubuntu-server-jammy'
          sku: '22_04-lts-gen2'
          version: 'latest'
        }
        osDisk: {
          createOption: 'FromImage'
          caching: 'ReadWrite'
          diskSizeGB: runnerExecutionConfig.osDiskSizeGb
          managedDisk: {
            storageAccountType: 'StandardSSD_LRS'
          }
        }
      }
      osProfile: {
        computerNamePrefix: take(runnerScaleSetName, 9)
        adminUsername: runnerExecutionConfig.adminUsername
        customData: base64(cloudInit)
        linuxConfiguration: {
          disablePasswordAuthentication: true
          provisionVMAgent: true
          ssh: {
            publicKeys: [
              {
                path: '/home/${runnerExecutionConfig.adminUsername}/.ssh/authorized_keys'
                keyData: runnerExecutionConfig.adminPublicKey
              }
            ]
          }
        }
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: '${runnerScaleSetName}-nic'
            properties: {
              primary: true
              enableAcceleratedNetworking: false
              ipConfigurations: [
                {
                  name: 'ipconfig'
                  properties: {
                    subnet: {
                      id: infrastructureSubnetId
                    }
                  }
                }
              ]
            }
          }
        ]
      }
    }
  }
}

resource autoscalerStorage 'Microsoft.Storage/storageAccounts@2025-01-01' = if (deployRunnerPool) {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource autoscalerPlan 'Microsoft.Web/serverfarms@2024-11-01' = if (deployRunnerPool) {
  name: functionPlanName
  location: location
  tags: tags
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
    size: 'Y1'
    family: 'Y'
  }
  properties: {
    reserved: true
  }
}

resource runnerAutoscaler 'Microsoft.Web/sites@2024-11-01' = if (deployRunnerPool) {
  name: runnerAutoscalerFunctionAppName
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  tags: tags
  properties: {
    httpsOnly: true
    reserved: true
    serverFarmId: autoscalerPlan.id
    siteConfig: {
      linuxFxVersion: 'Python|3.11'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: autoscalerStorageConnectionString
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: autoscalerStorageConnectionString
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(take(replace(runnerAutoscalerFunctionAppName, '-', ''), 63))
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
        {
          name: 'ENABLE_ORYX_BUILD'
          value: 'true'
        }
        {
          name: 'GITHUB_ORG'
          value: runnerExecutionConfig.owner
        }
        {
          name: 'RUNNER_LABEL'
          value: first(runnerExecutionConfig.runnerLabels)
        }
        {
          name: 'TARGET_REPOSITORIES'
          value: targetRepositoriesCsv
        }
        {
          name: 'VMSS_RESOURCE_ID'
          value: runnerVmss.id
        }
        {
          name: 'MAX_RUNNERS'
          value: string(runnerExecutionConfig.maxRunners)
        }
        {
          name: 'GITHUB_PAT'
          value: '@Microsoft.KeyVault(SecretUri=${patSecretUri})'
        }
        {
          name: 'GITHUB_WEBHOOK_SECRET'
          value: '@Microsoft.KeyVault(SecretUri=${webhookSecretUri})'
        }
      ]
    }
  }
}

resource runnerAutoscalerVmssAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployRunnerPool) {
  name: guid(runnerVmss.id, runnerAutoscaler.id, 'runner-autoscaler-vmss-contributor')
  scope: runnerVmss
  properties: {
    roleDefinitionId: virtualMachineContributorRoleDefinitionId
    principalId: runnerAutoscaler!.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output runnerPlatform object = {
  resourceGroupName: resourceGroup().name
  vmScaleSet: {
    name: runnerScaleSetName
    id: deployRunnerPool ? runnerVmss.id : null
    subnetId: infrastructureSubnetId
    minRunners: runnerExecutionConfig.minRunners
    maxRunners: runnerExecutionConfig.maxRunners
    privateConnectivity: [
      'Runner VMs live on the dedicated hub runner subnet with no per-instance public IPs.'
      'Outbound access to GitHub and package sources is expected to use the subnet NAT path rather than direct inbound exposure.'
    ]
  }
  identities: {
    execution: {
      name: runnerExecutionIdentityName
      resourceId: deployRunnerPool ? runnerExecutionIdentity.id : null
      principalId: deployRunnerPool ? runnerExecutionIdentity!.properties.principalId : null
      roleAssignments: []
      workloadAccessModel: 'Assign Azure RBAC for deployment targets to the runner execution identity outside the shared platform baseline.'
    }
  }
  autoscaler: {
    functionApp: {
      name: runnerAutoscalerFunctionAppName
      resourceId: deployRunnerPool ? runnerAutoscaler!.id : null
      principalId: deployRunnerPool ? runnerAutoscaler!.identity.principalId : null
      defaultHostname: deployRunnerPool ? runnerAutoscaler!.properties.defaultHostName : null
      webhookUrl: deployRunnerPool ? 'https://${runnerAutoscaler!.properties.defaultHostName}/api/workflow-job-webhook' : null
    }
    storageAccount: {
      name: deployRunnerPool ? autoscalerStorage!.name : null
      resourceId: deployRunnerPool ? autoscalerStorage!.id : null
    }
    scalingModel: [
      'The autoscaler reacts to GitHub workflow_job webhook events.'
      'Queued jobs increase VMSS capacity one runner at a time up to the configured maximum.'
      'Completed jobs scale the VMSS back to zero once no matching runners remain busy.'
    ]
  }
  secretHandlingModel: [
    'The VM scale set bootstrap retrieves the GitHub registration PAT from Key Vault through the runner execution managed identity.'
    'The autoscaler Function App consumes the GitHub PAT and webhook secret through Key Vault references rather than storing them inline in the template.'
    'Registration tokens remain short-lived and are requested from GitHub at runner startup; they are never stored in Key Vault.'
  ]
  platformConstraints: [
    'Register runners at the GitHub organization scope and keep them in the HexMaster Landingzone runner group.'
    'VMSS capacity defaults to zero. Runners are provisioned on demand when a workflow_job queued event arrives and scale back to zero when no runners are busy.'
    'Linux runners install Docker so workflows can use container actions and service containers.'
  ]
}
