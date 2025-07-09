param name string
param location string = resourceGroup().location
param tags object = {}

// Networking
param privateLinkScopeName string

resource privateLinkScope 'Microsoft.Insights/privateLinkScopes@2021-07-01-preview' existing = if (privateLinkScopeName != '') {
  name: privateLinkScopeName
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2025-02-01' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': name })
  properties: any({
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
    sku: {
      name: 'PerGB2018'
    }
    publicNetworkAccessForIngestion: privateLinkScopeName != '' ? 'Disabled' : 'Enabled'
    publicNetworkAccessForQuery: privateLinkScopeName != '' ? 'Enabled' : 'Enabled'
  })
}

resource logAnalyticsScopedResource 'Microsoft.Insights/privateLinkScopes/scopedResources@2023-06-01-preview' = if (privateLinkScopeName != '') {
  parent: privateLinkScope
  name: '${logAnalytics.name}-connection'
  properties: {
    linkedResourceId: logAnalytics.id
  }
}

output id string = logAnalytics.id
output name string = logAnalytics.name
