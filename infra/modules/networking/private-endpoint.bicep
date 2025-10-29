param name string
param privateLinkServiceId string
param groupIds array
param dnsZoneNames array = []
param location string

param privateEndpointSubnetId string
param dnsZoneRG string
param dnsSubId string

resource privateEndpointDnsZones 'Microsoft.Network/privateDnsZones@2024-06-01' existing = [
  for zoneName in dnsZoneNames: {
    name: zoneName
    scope: resourceGroup(dnsSubId, dnsZoneRG)
  }
]

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-10-01' = {
  name: name
  location: location
  dependsOn: [
    privateEndpointDnsZones
  ]
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: name
        properties: {
          privateLinkServiceId: privateLinkServiceId
          groupIds: groupIds
        }
      }
    ]
  }

  resource privateDnsZoneGroups 'privateDnsZoneGroups' = {
    name: 'privateDnsZoneGroup'
    properties: {
      privateDnsZoneConfigs: [
        for (zoneName, index) in dnsZoneNames: {
          name: zoneName
          properties: {
            privateDnsZoneId: privateEndpointDnsZones[index].id
          }
        }
      ]
    }
  }
}

output privateEndpointName string = privateEndpoint.name
