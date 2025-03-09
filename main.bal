import ballerinax/ai.agent;

configurable string apiKey = ?;
configurable string deploymentId = ?;
configurable string apiVersion = ?;
configurable string serviceUrl = ?;

configurable string pineconeServiceUrl = ?;
configurable string pineconeKey = ?;
configurable string pineconeNamespace = ?;
configurable string openAiEmbeddingKey = ?;

isolated function createFaqRetrieverTool(Retriever retriever) returns agent:ToolConfig {
    agent:ToolConfig faqRetrieverTool = retriever.getTools().pop();
    faqRetrieverTool.name = "FAQ_InformationRetriever";
    faqRetrieverTool.description = "Retrieves relevant FAQ information about the Ballerina programming language," +
    " including its features, usage, best practices, and latest updates. " +
    "Always use this tool to provide accurate and up-to-date Ballerina-related knowledge.";
    return faqRetrieverTool;
}

final PineconeConfig pineconeConfig = {serviceUrl: pineconeServiceUrl, apiKey: pineconeKey, namespace: pineconeNamespace};
final OpenAiEmbeddingModelConfig embeddingModelConfig = {apiKey: openAiEmbeddingKey, modelName: "text-embedding-3-small"};
final Retriever retriever = check new Retriever(pineconeConfig, embeddingModelConfig);

// public function main() returns error? {
//     string faqContent = check io:fileReadString("./resources/FAQ.md");

//     // Break the text in to 2000 char blocks
//     int contentLength = faqContent.length();
//     int blockSize = 2000;
//     int blockCount = 0;
//     string[] blocks = [];
//     while (blockCount * blockSize < contentLength) {
//         int startIndex = blockCount * blockSize;
//         int endIndex = startIndex + blockSize;

//         if (endIndex > contentLength) {
//             endIndex = contentLength;
//         }
//         string block = faqContent.substring(startIndex, endIndex);
//         blocks.push(block);
//         blockCount += 1;
//     }

//     // Perform data ingestion
//     check faqRetriver.storeEmbedding(blocks);
//     io:println("Successfully ingested");
// }

final agent:SystemPrompt systemPrompt = {
    role: "FAQ Assistant",
    instructions: "You are an intelligent FAQ assistant designed to provide clear, concise, and accurate answers to user inquiries. " +
    "Maintain a professional yet approachable tone. Prioritize factual accuracy and relevance. " +
    "If a question requires additional context, politely ask for clarification. " +
    "Avoid speculation and ensure responses align with the provided knowledge base. " +
    "Keep responses brief but informative, and where necessary, guide users to further resources."
};
final agent:Model model = check new agent:AzureOpenAiModel({auth: {apiKey}}, serviceUrl, deploymentId, apiVersion);
final agent:Agent agent = check new (systemPrompt = systemPrompt, model = model,
    tools = [retriever],
    verbose = true
);

service on new agent:Listener(8090) {
    remote function onChatMessage(agent:ChatReqMessage request) returns agent:ChatRespMessage|error {
        string response = check agent->run(request.message, memoryId = request.sessionId);
        return {message: response};
    }
}
