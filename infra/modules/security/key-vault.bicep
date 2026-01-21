param location string
param keyVaultName string
param keyVaultSkuName string = 'standard'

param roleAssignments array = []

param publicNetworkAccess string = 'Disabled'
param privateEndpointName string
param vNetRG string
param vNetName string
param privateEndpointSubnetName string
param privateDnsZoneName string

param ipRules array = []
param virtualNetworkRules array = []

// Use existing network/dns zone
param dnsZoneRG string
param dnsSubscriptionId string

param tags object = {}

resource vnet 'Microsoft.Network/virtualNetworks@2024-07-01' existing = {
  name: vNetName
  scope: resourceGroup(vNetRG)
}

// Get existing subnet
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2024-07-01' existing = {
  name: privateEndpointSubnetName
  parent: vnet
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  name: privateDnsZoneName
  scope: resourceGroup(dnsSubscriptionId, dnsZoneRG)
}

module vault 'br/public:avm/res/key-vault/vault:0.13.0' = {
  name: 'vault'
  params: {
    tags: tags
    name: keyVaultName
    enablePurgeProtection: false
    enableRbacAuthorization: true
    location: location
    sku: keyVaultSkuName
    roleAssignments: roleAssignments
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      defaultAction: 'Deny'
      ipRules: ipRules
      virtualNetworkRules: virtualNetworkRules
    }
    privateEndpoints: [
      {
        name: privateEndpointName
        subnetResourceId: subnet.id
        privateDnsZoneGroup: {
          name: 'default'
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: privateDnsZone.id
            }
          ]
        }
      }
    ]
  }
}

output resourceId string = vault.outputs.resourceId
