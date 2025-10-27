import * as utils from 'br:mcr.microsoft.com/bicep/avm/res/cognitive-services/account:0.10.0'

param name string
param location string = resourceGroup().location
param tags object = {}
param managedIdentityName string = ''
param deployments array = []
param kind string = 'OpenAI'
param sku object = {
  name: 'S0'
}
param deploymentCapacity int = 1

// Networking
param publicNetworkAccess string = 'Disabled'
param privateEndpointName string
param disableLocalAuth bool = true
param vNetName string
param vNetLocation string
param privateEndpointSubnetName string
param privateDnsZoneName string

param ipRules array = []
param virtualNetworkRules array = []

// Use existing network/dns zone
param dnsZoneRG string
param dnsSubscriptionId string
param vNetRG string

param secretsExportConfiguration utils.secretsExportConfigurationType?

resource vnet 'Microsoft.Network/virtualNetworks@2024-07-01' existing = {
  name: vNetName
  scope: resourceGroup(vNetRG)
}

// Get existing subnet
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2024-07-01' existing = {
  name: privateEndpointSubnetName
  parent: vnet
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' existing = {
  name: managedIdentityName
}

resource account 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': name })
  kind: kind
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    disableLocalAuth: kind == 'TextAnalytics' ? false : disableLocalAuth
    customSubDomainName: toLower(name)
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      defaultAction: 'Deny'
      ipRules: ipRules
      virtualNetworkRules: virtualNetworkRules
    }
  }
  sku: sku
}

@batchSize(1)
resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = [
  for deployment in deployments: {
    parent: account
    name: deployment.name
    properties: {
      model: deployment.model
      raiPolicyName: deployment.?raiPolicyName ?? null
    }
    sku: deployment.?sku ?? {
      name: 'Standard'
      capacity: deploymentCapacity
    }
  }
]

module privateEndpoint '../networking/private-endpoint.bicep' = {
  name: '${account.name}-privateEndpoint'
  params: {
    groupIds: [
      'account'
    ]
    dnsZoneName: privateDnsZoneName
    name: privateEndpointName
    privateLinkServiceId: account.id
    location: vNetLocation
    privateEndpointSubnetId: subnet.id
    dnsZoneRG: dnsZoneRG
    dnsSubId: dnsSubscriptionId
  }
  dependsOn: [
    deployment
  ]
}

// Copied from: https://github.com/Azure/bicep-registry-modules/blob/7732c3fd13eb502fdbd30d8c51f88ed3c0ae5dc9/avm/res/cognitive-services/account/main.bicep#L489

module secretsExport '../security/keyVaultExport.bicep' = if (secretsExportConfiguration != null) {
  name: '${account.name}-secrets-kv'
  scope: resourceGroup(
    split(secretsExportConfiguration.?keyVaultResourceId!, '/')[2],
    split(secretsExportConfiguration.?keyVaultResourceId!, '/')[4]
  )
  params: {
    keyVaultName: last(split(secretsExportConfiguration.?keyVaultResourceId!, '/'))
    secretsToSet: union(
      [],
      contains(secretsExportConfiguration!, 'accessKey1Name')
        ? [
            {
              name: secretsExportConfiguration!.?accessKey1Name
              value: account.listKeys().key1
            }
          ]
        : [],
      contains(secretsExportConfiguration!, 'accessKey2Name')
        ? [
            {
              name: secretsExportConfiguration!.?accessKey2Name
              value: account.listKeys().key2
            }
          ]
        : []
    )
  }
}

output name string = account.name
output endpointUri string = kind == 'OpenAI' ? '${account.properties.endpoint}openai/' : account.properties.endpoint
import { secretsOutputType } from 'br/public:avm/utl/types/avm-common-types:0.4.0'
@description('A hashtable of references to the secrets exported to the provided Key Vault. The key of each reference is each secret\'s name.')
output exportedSecrets secretsOutputType = (secretsExportConfiguration != null)
  ? toObject(secretsExport.outputs.secretsSet, secret => last(split(secret.secretResourceId, '/')), secret => secret)
  : {}
