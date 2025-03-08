// import ballerina/io;
import ballerinax/ai.agent;

configurable string apiKey = ?;
configurable string deploymentId = ?;
configurable string apiVersion = ?;
configurable string serviceUrl = ?;

configurable string pineconeServiceUrl = ?;
configurable string pineconeKey = ?;
configurable string pineconeNamespace = ?;
configurable string openAiEmbeddingToken = ?;

final Retriever faqRetriver = check new Retriever(
    toolName = "FAQ_InformationRetriever",
    toolDescription = "Retrieves relevant FAQ information about the Ballerina programming language," +
    " including its features, usage, best practices, and latest updates. " +
    "Always use this tool to provide accurate and up-to-date Ballerina-related knowledge.",
    pineconeServiceUrl = pineconeServiceUrl,
    pineconeKey = pineconeKey,
    pineconeNamespace = pineconeNamespace,
    openAiEmbeddingToken = openAiEmbeddingToken,
    topK = 1
);

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
    tools = [faqRetriver],
    verbose = true
);

service on new agent:Listener(8090) {
    remote function onChatMessage(agent:ChatReqMessage request) returns agent:ChatRespMessage|error {
        string response = check agent->run(request.message, memoryId = request.sessionId);
        return {message: response};
    }
}
