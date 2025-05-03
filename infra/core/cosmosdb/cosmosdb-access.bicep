param cosmosDbName string
param roleDefinitionID string
param principalID string
param subscriptionId string
param resourceGroupName string


param roleID string = '/subscriptions/${subscriptionId}/resourceGroups/${resourceGroupName}/providers/Microsoft.DocumentDB/databaseAccounts/${cosmosDbName}/sqlRoleDefinitions/${roleDefinitionID}'

resource account 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' existing = {
  name: cosmosDbName
}

resource assignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-05-15' = {
  name: guid(roleDefinitionID, principalID, account.id)
  parent: account
  properties: {
    principalId: principalID
    roleDefinitionId: roleID
    scope: account.id
  }
}
