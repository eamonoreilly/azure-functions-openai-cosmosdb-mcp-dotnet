using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Extensions.OpenAI.Embeddings;
using Microsoft.Azure.Functions.Worker.Extensions.OpenAI.Search;
using Microsoft.Azure.Functions.Worker.Extensions.Mcp;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;
using System.Net;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace CosmosDBSampleMCP
{
    public class SemanticSearch
    {
        private readonly ILogger<SemanticSearch> _logger;

        public SemanticSearch(ILogger<SemanticSearch> logger)
        {
            _logger = logger;
        }

        /// <summary>
        /// HTTP trigger that takes a body in the format below and adds it to the Cosmos DB semantic search.
        /// {
        ///    "Text": "Contoso support incident 3455 is about slow performance.",
        ///    "Title": "Contoso3455"
        /// }
        /// </summary>
        [Function("ingestdata")]
        public async Task<EmbeddingsStoreOutputResponse> IngestData(
            [HttpTrigger(AuthorizationLevel.Anonymous, "post")] HttpRequestData req)
        {
            using StreamReader reader = new(req.Body);
            string request = await reader.ReadToEndAsync();

            EmbeddingsRequest? requestBody = JsonSerializer.Deserialize<EmbeddingsRequest>(request);

            if (requestBody?.Title == null)
            {
                return new EmbeddingsStoreOutputResponse
                {
                    HttpResponse = new BadRequestObjectResult(new { status = HttpStatusCode.BadRequest, message = "Title of content is required" })
                };
            }

            _logger.LogInformation("Ingest function called with title: {Title}", requestBody.Title);

            return new EmbeddingsStoreOutputResponse
            {
                HttpResponse = new OkObjectResult(new { status = HttpStatusCode.OK, message = "Text ingested into Cosmos DB" }),
                SearchableDocument = new SearchableDocument(requestBody.Title)
            };
        }

        // Extract Title from request body
        public class EmbeddingsRequest
        {
            [JsonPropertyName("Title")]
            public string? Title { get; set; }
        }

        /// <summary>
        /// Embeds content using the EmbeddingsStoreOutput binding from the Text field in request body, and document title and sends a HTTP response to client
        /// </summary>
        public class EmbeddingsStoreOutputResponse
        {
            [EmbeddingsStoreOutput("{Text}", InputType.RawText, "COSMOSDB", "rag", EmbeddingsModel = "%EMBEDDING_MODEL_DEPLOYMENT_NAME%")]
            public SearchableDocument? SearchableDocument { get; init; }

           [HttpResult]
            public IActionResult? HttpResponse { get; set; }
        }

        /// <summary>
        /// HTTP trigger that takes a question and returns a response from the Cosmos DB service. Body should take the format below.
        /// {
        ///   "question": "What is support incident 3455 about?",
        /// }
        /// </summary>
        [Function("prompt")]
        public IActionResult Prompt(
            [HttpTrigger(AuthorizationLevel.Anonymous, Route = "prompt")] HttpRequestData req,
            [SemanticSearchInput(
                        "COSMOSDB",
                        "rag",
                        Query = "{question}",
                        ChatModel = "%CHAT_MODEL_DEPLOYMENT_NAME%",
                        EmbeddingsModel = "%EMBEDDING_MODEL_DEPLOYMENT_NAME%",
                        SystemPrompt = "%SYSTEM_PROMPT%"
                    )]
                    SemanticSearchContext result)
        {
            _logger.LogInformation("Ask function called...");

            return new OkObjectResult(result.Response);
        }

        /// <summary>
        /// MCP tool that retrieves support incident information based on a search prompt.
        /// </summary>
        [Function("GetSupportInformation")]
        public string GetSupportInformation(
            [McpToolTrigger("GetSupportInformation", "Retrieves support incident information based on a search prompt.")]
            ToolInvocationContext context,
            [McpToolProperty("searchText", "string", "The search text to use for retrieving support incident information. This should be in a complete sentence format.")]
            string searchText,
            [SemanticSearchInput(
                "COSMOSDB",
                "rag",
                Query = "{arguments.searchText}",
                ChatModel = "%CHAT_MODEL_DEPLOYMENT_NAME%",
                EmbeddingsModel = "%EMBEDDING_MODEL_DEPLOYMENT_NAME%",
                SystemPrompt = "%SYSTEM_PROMPT%"
            )]
            SemanticSearchContext result)
        {
            return result.Response;
        }

    }
}