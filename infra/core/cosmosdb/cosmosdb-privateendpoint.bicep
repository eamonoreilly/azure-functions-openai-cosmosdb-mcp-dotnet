// Parameters
@description('Specifies the name of the virtual network.')
param virtualNetworkName string

@description('Specifies the name of the subnet.')
param subnetName string

@description('Specifies the resource with an endpoint.')
param resourceName string

@description('Specifies the location.')
param location string = resourceGroup().location

param tags object = {}

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2021-08-01' existing = {
  name: virtualNetworkName
}

resource cosmosdb 'microsoft.documentdb/databaseaccounts@2023-09-15' existing = {
  name: resourceName
}

var cosmosdbPrivateDNSZoneName = 'privatelink.documents.azure.com'

// Private DNS Zones
resource cosmosdbPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: cosmosdbPrivateDNSZoneName
  location: 'global'
  tags: tags
  properties: {}
  dependsOn: [
    vnet
  ]
}

// Virtual Network Links
resource cosmosdbPrivateDnsZoneVirtualNetworkLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: cosmosdbPrivateDnsZone
  name: uniqueString(vnet.id)
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

// Private Endpoints
resource cosmosdbPrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-08-01' = {
  name: 'cosmosdb-private-endpoint'
  location: location
  tags: tags
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'cosmosdbPrivateLinkConnection'
        properties: {
          privateLinkServiceId: cosmosdb.id
          groupIds: [
            'SQL'
          ]
        }
      }
    ]
    subnet: {
      id: '${vnet.id}/subnets/${subnetName}'
    }
  }
}

resource cosmosdbPrivateDnsZoneGroupName 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-01-01' = {
  parent: cosmosdbPrivateEndpoint
  name: 'cosmosdbPrivateDnsZoneGroup'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'cosmosdbRecord'
        properties: {
          privateDnsZoneId: cosmosdbPrivateDnsZone.id
        }
      }
    ]
  }
}
