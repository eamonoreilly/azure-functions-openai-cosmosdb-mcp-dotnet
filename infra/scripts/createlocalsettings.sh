#!/bin/bash

set -e

if [ ! -f "./app/local.settings.json" ]; then

    output=$(azd env get-values)

    # Initialize variables
    CosmosDBEndPoint=""
    OpenAIEndPoint=""

    # Parse the output to get the endpoint URLs
    while IFS= read -r line; do
        if [[ $line == *"AZURE_COSMOSDB_ENDPOINT"* ]]; then
            CosmosDBEndPoint=$(echo "$line" | cut -d '=' -f 2 | tr -d '"')
        fi
        if [[ $line == *"AZURE_OPENAI_ENDPOINT"* ]]; then
            OpenAIEndPoint=$(echo "$line" | cut -d '=' -f 2 | tr -d '"')
        fi
    done <<< "$output"

    cat <<EOF > ./app/local.settings.json
{
    "IsEncrypted": "false",
    "Values": {
        "AzureWebJobsStorage": "UseDevelopmentStorage=true",
        "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated",
        "AZURE_OPENAI_ENDPOINT": "$OpenAIEndPoint",
        "CHAT_MODEL_DEPLOYMENT_NAME": "chat",
        "COSMOSDB__ENDPOINT": "$CosmosDBEndPoint",
        "EMBEDDING_MODEL_DEPLOYMENT_NAME": "embeddings",
        "SYSTEM_PROMPT": "You must only use the provided documents to answer the question"
    }
}
EOF

fi