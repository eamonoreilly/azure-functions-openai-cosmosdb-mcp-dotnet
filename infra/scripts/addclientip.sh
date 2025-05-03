#!/bin/bash
set -e

# Get environment values
output=$(azd env get-values)

# Parse the output to get the resource names and the resource group
while IFS= read -r line; do
    if [[ $line == AZURE_COSMOSDB_ACCOUNT_NAME* ]]; then
        CosmosDBResourceName=$(echo "$line" | cut -d '=' -f 2 | tr -d '"')
    elif [[ $line == AZURE_OPENAI_NAME* ]]; then
        OpenAIResourceName=$(echo "$line" | cut -d '=' -f 2 | tr -d '"')
    elif [[ $line == RESOURCE_GROUP* ]]; then
        ResourceGroup=$(echo "$line" | cut -d '=' -f 2 | tr -d '"')
    fi
done <<< "$output"

# Read the config.json file to see if vnet is enabled
ConfigFolder=$(echo "$ResourceGroup" | cut -d '-' -f 2-)
jsonContent=$(cat ".azure/$ConfigFolder/config.json")
EnableVirtualNetwork=$(echo "$jsonContent" | jq -r '.infra.parameters.EnableVirtualNetwork')

if [[ $EnableVirtualNetwork == "false" ]]; then
    echo "VNet is not enabled. Skipping adding the client IP to the network rule of the Azure OpenAI and the Azure Cosmos DB services"
else
    echo "VNet is enabled. Adding the client IP to the network rule of the Azure OpenAI and the Azure Cosmos DB services"

    # Get the client IP
    ClientIP=$(curl -s https://api.ipify.org)

    # Check and update Azure OpenAI network rules
    Rules=$(az cognitiveservices account show --resource-group "$ResourceGroup" --name "$OpenAIResourceName" --query "properties.networkAcls.ipRules" -o json)
    IPExists=$(echo "$Rules" | jq -r --arg ip "$ClientIP" '.[] | select(.value == $ip) | .value')

    if [[ -z $IPExists ]]; then
        echo "Adding the client IP $ClientIP to the network rule of the Azure OpenAI service $OpenAIResourceName"
        az cognitiveservices account network-rule add --resource-group "$ResourceGroup" --name "$OpenAIResourceName" --ip-address "$ClientIP" > /dev/null
        OpenAIResourceId=$(az cognitiveservices account show --resource-group "$ResourceGroup" --name "$OpenAIResourceName" --query id -o tsv)
        az resource update --ids "$OpenAIResourceId" --set properties.publicNetworkAccess="Enabled" > /dev/null
    else
        echo "The client IP $ClientIP is already in the network rule of the Azure OpenAI service $OpenAIResourceName"
    fi

    # Check and update Azure CosmosDB network rules
    Rules=$(az cosmosdb show --resource-group "$ResourceGroup" --name "$CosmosDBResourceName" --query "ipRules" -o json)
    IPExists=$(echo "$Rules" | jq -r --arg ip "$ClientIP" '.[] | select(.value == $ip) | .value')

    if [[ -z $IPExists ]]; then
        echo "Adding the client IP $ClientIP to the network rule of the Azure CosmosDB service $CosmosDBResourceName"
        az cosmosdb update --resource-group "$ResourceGroup" --name "$CosmosDBResourceName" --ip-range-filter "$ClientIP" > /dev/null
        CosmosDBResourceId=$(az cosmosdb show --resource-group "$ResourceGroup" --name "$CosmosDBResourceName" --query id -o tsv)
        az resource update --ids "$CosmosDBResourceId" --set properties.publicNetworkAccess="Enabled" > /dev/null
    else
        echo "The client IP $ClientIP is already in the network rule of the Azure Cosmos DB service $CosmosDBResourceName"
    fi
fi
