targetScope = 'resourceGroup'

@description('Azure region for shared platform services.')
param location string

@description('Tags applied to shared platform services.')
param tags object = {}

@description('Hub VNet resource ID linked to private DNS zones.')
param hubVirtualNetworkId string

@description('Subnet resource ID used for private endpoints.')
param privateEndpointSubnetId string

@description('Name of the central Azure Container Registry.')
param containerRegistryName string

@description('Name of the shared platform Key Vault that stores runner secrets and future platform secrets.')
param keyVaultName string

@description('Shared-service hosting configuration for central registry and secret storage.')
param sharedServicesConfig object = {
  registry: {
    sku: 'Premium'
    publicNetworkAccess: 'Disabled'
  }
  secretVault: {
    sku: 'standard'
    publicNetworkAccess: 'Disabled'
    enablePurgeProtection: true
  }
  hostingModel: {
    platformResourceGroupPlacement: 'DedicatedPlatformResourceGroup'
    sharedServicesSubnetPurpose: 'HubHostedPlatformServicesOnly'
    privateEndpointSubnetPurpose: 'PrivateEndpointsAndPrivateDnsOnly'
    spokeConsumptionPattern: 'UseHubPrivateDnsLinksAndHubPrivateEndpoints'
  }
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2025-04-01' = {
  name: containerRegistryName
  location: location
  tags: tags
  sku: {
    name: sharedServicesConfig.registry.sku
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: sharedServicesConfig.registry.publicNetworkAccess
    networkRuleBypassOptions: 'AzureServices'
  }
}

resource platformKeyVault 'Microsoft.KeyVault/vaults@2024-11-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: sharedServicesConfig.secretVault.sku == 'premium' ? 'premium' : 'standard'
    }
    enableRbacAuthorization: true
    enablePurgeProtection: sharedServicesConfig.secretVault.enablePurgeProtection
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    publicNetworkAccess: sharedServicesConfig.secretVault.publicNetworkAccess
    softDeleteRetentionInDays: 90
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
    }
  }
}

resource acrPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.azurecr.io'
  location: 'global'
  tags: tags
}

resource acrPrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: acrPrivateDnsZone
  name: 'hub-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: hubVirtualNetworkId
    }
  }
}

resource keyVaultPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
  tags: tags
}

resource keyVaultPrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: keyVaultPrivateDnsZone
  name: 'hub-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: hubVirtualNetworkId
    }
  }
}

resource containerRegistryPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: 'pep-${containerRegistryName}'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'acr-registry'
        properties: {
          privateLinkServiceId: containerRegistry.id
          groupIds: [
            'registry'
          ]
        }
      }
    ]
  }
}

resource containerRegistryPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: containerRegistryPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'acr-registry'
        properties: {
          privateDnsZoneId: acrPrivateDnsZone.id
        }
      }
    ]
  }
}

resource keyVaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: 'pep-${keyVaultName}'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'vault'
        properties: {
          privateLinkServiceId: platformKeyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

resource keyVaultPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: keyVaultPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'vault'
        properties: {
          privateDnsZoneId: keyVaultPrivateDnsZone.id
        }
      }
    ]
  }
}

output sharedServices object = {
  resourceGroupScope: resourceGroup().name
  hostingModel: {
    platformResourceGroupPlacement: sharedServicesConfig.hostingModel.platformResourceGroupPlacement
    sharedServicesSubnetPurpose: sharedServicesConfig.hostingModel.sharedServicesSubnetPurpose
    privateEndpointSubnetPurpose: sharedServicesConfig.hostingModel.privateEndpointSubnetPurpose
    spokeConsumptionPattern: sharedServicesConfig.hostingModel.spokeConsumptionPattern
    assumptions: [
      'Hub-hosted shared services stay in the platform resource group and are consumed from spokes through private endpoints and hub-linked private DNS zones.'
      'Future shared platform services that need private consumption should reuse the shared services resource group and the private endpoints subnet instead of introducing workload resources into the hub.'
    ]
  }
  containerRegistry: {
    name: containerRegistry.name
    id: containerRegistry.id
    loginServer: containerRegistry.properties.loginServer
    sku: sharedServicesConfig.registry.sku
    publicNetworkAccess: sharedServicesConfig.registry.publicNetworkAccess
    privateEndpointId: containerRegistryPrivateEndpoint.id
    privateDnsZoneId: acrPrivateDnsZone.id
    imageConsumptionPattern: [
      'Runner jobs pull images from the central registry with a dedicated managed identity.'
      'Future workload spokes consume shared images over the hub-linked privatelink.azurecr.io zone.'
      'Enable ACR ARM-audience authentication before first runner image pull so Container Apps managed identities can authenticate without admin credentials.'
    ]
  }
  secretVault: {
    name: platformKeyVault.name
    id: platformKeyVault.id
    vaultUri: platformKeyVault.properties.vaultUri
    publicNetworkAccess: sharedServicesConfig.secretVault.publicNetworkAccess
    privateEndpointId: keyVaultPrivateEndpoint.id
    privateDnsZoneId: keyVaultPrivateDnsZone.id
    secretHandlingNotes: [
      'Store GitHub personal access tokens or equivalent bootstrap secrets in Key Vault rather than as deployment-time plain text parameters.'
      'Grant the runner execution identity least-privilege Key Vault secret access and keep operator access on separate RBAC assignments.'
    ]
  }
}
