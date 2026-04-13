targetScope = 'resourceGroup'

@description('Azure region for the runner execution platform.')
param location string

@description('Tags applied to runner platform resources.')
param tags object = {}

@description('Name of the Container Apps managed environment hosting runner jobs.')
param containerAppsEnvironmentName string

@description('Name of the GitHub Actions runner job definition.')
param runnerJobName string

@description('Name of the runner execution identity used inside the job.')
param runnerExecutionIdentityName string

@description('Name of the runner registry identity used for ACR pulls.')
param runnerRegistryIdentityName string

@description('Name of the central Azure Container Registry in this resource group.')
param containerRegistryName string

@description('Name of the shared platform Key Vault in this resource group.')
param keyVaultName string

@description('Subnet resource ID delegated to the Container Apps environment.')
param infrastructureSubnetId string

@description('Runner execution configuration for the Container Apps environment and GitHub runner job.')
param runnerExecutionConfig object = {
  deployRunnerJob: false
  imageRepository: 'github-actions-runner'
  imageTag: 'latest'
  githubApiUrl: 'https://api.github.com'
  githubUrl: ''
  runnerScope: 'repo'
  owner: ''
  repositories: []
  targetWorkflowQueueLength: 1
  minExecutions: 0
  maxExecutions: 5
  pollingInterval: 30
  replicaTimeout: 1800
  replicaRetryLimit: 0
  replicaCompletionCount: 1
  parallelism: 1
  cpu: 2
  memory: '4Gi'
  githubPatSecretName: 'github-actions-pat'
  githubPatSecretUri: ''
  registrationTokenApiUrl: ''
  environmentNetwork: {
    dockerBridgeCidr: '10.255.0.0/16'
    platformReservedCidr: '10.254.0.0/16'
    platformReservedDnsIP: '10.254.0.10'
  }
}

var acrPullRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
var keyVaultSecretsUserRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
var deployRunnerJob = runnerExecutionConfig.deployRunnerJob && !empty(runnerExecutionConfig.githubUrl) && !empty(runnerExecutionConfig.registrationTokenApiUrl) && !empty(runnerExecutionConfig.githubPatSecretUri)
var runnerImage = '${containerRegistry.properties.loginServer}/${runnerExecutionConfig.imageRepository}:${runnerExecutionConfig.imageTag}'

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2025-04-01' existing = {
  name: containerRegistryName
}

resource platformKeyVault 'Microsoft.KeyVault/vaults@2024-11-01' existing = {
  name: keyVaultName
}

resource runnerRegistryIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: runnerRegistryIdentityName
  location: location
  tags: tags
}

resource runnerExecutionIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: runnerExecutionIdentityName
  location: location
  tags: tags
}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2025-01-01' = {
  name: containerAppsEnvironmentName
  location: location
  tags: tags
  properties: {
    #disable-next-line BCP037
    publicNetworkAccess: 'Disabled'
    appLogsConfiguration: {
      destination: 'none'
    }
    vnetConfiguration: {
      infrastructureSubnetId: infrastructureSubnetId
      internal: true
      dockerBridgeCidr: runnerExecutionConfig.environmentNetwork.dockerBridgeCidr
      platformReservedCidr: runnerExecutionConfig.environmentNetwork.platformReservedCidr
      platformReservedDnsIP: runnerExecutionConfig.environmentNetwork.platformReservedDnsIP
    }
  }
}

resource runnerRegistryAcrPullAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerRegistry.id, runnerRegistryIdentity.id, 'runner-acr-pull')
  scope: containerRegistry
  properties: {
    roleDefinitionId: acrPullRoleDefinitionId
    principalId: runnerRegistryIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource runnerExecutionKeyVaultAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(platformKeyVault.id, runnerExecutionIdentity.id, 'runner-key-vault-secrets-user')
  scope: platformKeyVault
  properties: {
    roleDefinitionId: keyVaultSecretsUserRoleDefinitionId
    principalId: runnerExecutionIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource githubRunnerJob 'Microsoft.App/jobs@2025-01-01' = if (deployRunnerJob) {
  name: runnerJobName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${runnerExecutionIdentity.id}': {}
      '${runnerRegistryIdentity.id}': {}
    }
  }
  properties: {
    environmentId: containerAppsEnvironment.id
    configuration: {
      triggerType: 'Event'
      replicaTimeout: runnerExecutionConfig.replicaTimeout
      replicaRetryLimit: runnerExecutionConfig.replicaRetryLimit
      registries: [
        {
          server: containerRegistry.properties.loginServer
          identity: runnerRegistryIdentity.id
        }
      ]
      secrets: [
        {
          name: runnerExecutionConfig.githubPatSecretName
          identity: runnerExecutionIdentity.id
          keyVaultUrl: runnerExecutionConfig.githubPatSecretUri
        }
      ]
      eventTriggerConfig: {
        parallelism: runnerExecutionConfig.parallelism
        replicaCompletionCount: runnerExecutionConfig.replicaCompletionCount
        scale: {
          minExecutions: runnerExecutionConfig.minExecutions
          maxExecutions: runnerExecutionConfig.maxExecutions
          pollingInterval: runnerExecutionConfig.pollingInterval
          rules: [
            {
              name: 'github-runner'
              type: 'github-runner'
              metadata: {
                githubAPIURL: runnerExecutionConfig.githubApiUrl
                owner: runnerExecutionConfig.owner
                runnerScope: runnerExecutionConfig.runnerScope
                repos: join(runnerExecutionConfig.repositories, ',')
                targetWorkflowQueueLength: string(runnerExecutionConfig.targetWorkflowQueueLength)
              }
              auth: [
                {
                  secretRef: runnerExecutionConfig.githubPatSecretName
                  triggerParameter: 'personalAccessToken'
                }
              ]
            }
          ]
        }
      }
    }
    template: {
      containers: [
        {
          name: 'github-runner'
          image: runnerImage
          env: [
            {
              name: 'GITHUB_PAT'
              secretRef: runnerExecutionConfig.githubPatSecretName
            }
            {
              name: 'GH_URL'
              value: runnerExecutionConfig.githubUrl
            }
            {
              name: 'REGISTRATION_TOKEN_API_URL'
              value: runnerExecutionConfig.registrationTokenApiUrl
            }
          ]
          resources: {
            cpu: runnerExecutionConfig.cpu
            memory: runnerExecutionConfig.memory
          }
        }
      ]
    }
  }
}

output runnerPlatform object = {
  environment: {
    name: containerAppsEnvironment.name
    id: containerAppsEnvironment.id
    subnetId: infrastructureSubnetId
    publicNetworkAccess: 'Disabled'
    boundaryNotes: [
      'The Container Apps environment is the runner execution boundary and is isolated from shared services by subnet separation.'
      'The environment is internal-only and uses the dedicated hub runner subnet rather than sharing workload spokes or operator connectivity resources.'
    ]
  }
  identities: {
    registryPull: {
      name: runnerRegistryIdentity.name
      resourceId: runnerRegistryIdentity.id
      principalId: runnerRegistryIdentity.properties.principalId
      roleAssignments: [
        runnerRegistryAcrPullAssignment.id
      ]
    }
    execution: {
      name: runnerExecutionIdentity.name
      resourceId: runnerExecutionIdentity.id
      principalId: runnerExecutionIdentity.properties.principalId
      roleAssignments: [
        runnerExecutionKeyVaultAssignment.id
      ]
      workloadAccessModel: 'Assign Azure RBAC for deployment targets to this identity outside the shared platform baseline.'
    }
  }
  job: {
    name: runnerJobName
    deploymentEnabled: deployRunnerJob
    triggerType: 'Event'
    image: runnerImage
    githubApiUrl: runnerExecutionConfig.githubApiUrl
    privateConnectivity: [
      'Runner executions start inside the hub-integrated Container Apps environment and resolve shared services through hub-linked private DNS zones.'
      'Image pulls use the dedicated registry identity against the private central ACR, and secret retrieval uses Key Vault over private endpoint connectivity.'
    ]
    secretHandlingModel: [
      'The job references a Key Vault secret URI for the GitHub PAT instead of storing PAT values in the template or repository.'
      'Only the runner execution identity receives Key Vault secret access; operators and future workload identities remain separate.'
    ]
    platformConstraints: [
      'Use this runner platform only for private repositories.'
      'Container Apps jobs do not support Docker-in-Docker workflows.'
    ]
  }
}
