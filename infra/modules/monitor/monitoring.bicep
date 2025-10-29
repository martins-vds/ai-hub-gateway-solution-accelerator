param logAnalyticsName string
param apimApplicationInsightsName string
param apimApplicationInsightsDashboardName string
param functionApplicationInsightsName string
param functionApplicationInsightsDashboardName string
param location string = resourceGroup().location
param tags object = {}

param createDashboard bool

// Networking
param usePrivateLinkScope bool = true
var privateLinkScopeName = 'ampls-monitoring'
param vNetName string
param privateEndpointSubnetName string
param applicationInsightsDnsZoneNames array = []

// Use existing network/dns zone
param dnsZoneRG string
param dnsSubscriptionId string
param vNetRG string

resource vnet 'Microsoft.Network/virtualNetworks@2024-07-01' existing = {
  name: vNetName
  scope: resourceGroup(vNetRG)
}

// Get existing subnet
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2024-07-01' existing = {
  name: privateEndpointSubnetName
  parent: vnet
}

resource privateLinkScope 'Microsoft.Insights/privateLinkScopes@2021-09-01' = if (usePrivateLinkScope) {
  name: privateLinkScopeName
  location: 'global'
  properties: {
    accessModeSettings: {
      ingestionAccessMode: 'Open'
      queryAccessMode: 'Open'
    }
  }
}

module logAnalytics 'loganalytics.bicep' = {
  name: 'log-analytics'
  params: {
    name: logAnalyticsName
    location: location
    tags: tags
    privateLinkScopeName: usePrivateLinkScope ? privateLinkScopeName : ''
  }
}

// APIM App Insights
module apimApplicationInsights 'applicationinsights.bicep' = {
  name: 'application-insights'
  params: {
    name: apimApplicationInsightsName
    location: location
    tags: tags
    dashboardName: apimApplicationInsightsDashboardName
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
    privateLinkScopeName: usePrivateLinkScope ? privateLinkScopeName : ''
    createDashboard: createDashboard
  }
}

// Function App Insights
module functionApplicationInsights 'applicationinsights.bicep' = {
  name: 'func-application-insights'
  params: {
    name: functionApplicationInsightsName
    location: location
    tags: tags
    dashboardName: functionApplicationInsightsDashboardName
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
    privateLinkScopeName: usePrivateLinkScope ? privateLinkScopeName : ''
    createDashboard: createDashboard
  }
}

module privateEndpoint '../networking/private-endpoint.bicep' = if (usePrivateLinkScope) {
  name: '${privateLinkScopeName}-privateEndpoint'
  params: {
    groupIds: [
      'azuremonitor'
    ]
    dnsZoneNames: applicationInsightsDnsZoneNames
    name: '${privateLinkScopeName}-pe'
    privateLinkServiceId: privateLinkScope.id
    location: location
    dnsZoneRG: dnsZoneRG
    privateEndpointSubnetId: subnet.id
    dnsSubId: dnsSubscriptionId
  }
  dependsOn: [
    logAnalytics
    apimApplicationInsights
    functionApplicationInsights
  ]
}

output applicationInsightsName string = apimApplicationInsights.outputs.name
output applicationInsightsConnectionString string = apimApplicationInsights.outputs.connectionString
output applicationInsightsInstrumentationKey string = apimApplicationInsights.outputs.instrumentationKey
output funcApplicationInsightsName string = functionApplicationInsights.outputs.name
output funcApplicationInsightsConnectionString string = functionApplicationInsights.outputs.connectionString
output funcApplicationInsightsInstrumentationKey string = functionApplicationInsights.outputs.instrumentationKey
output logAnalyticsWorkspaceId string = logAnalytics.outputs.id
output logAnalyticsWorkspaceName string = logAnalytics.outputs.name
