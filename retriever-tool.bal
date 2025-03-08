import ballerina/io;
import ballerina/lang.regexp;
import ballerina/uuid;
import ballerinax/ai.agent;
import ballerinax/openai.embeddings;
import ballerinax/pinecone.vector as pinecone;

isolated class Retriever {
    *agent:BaseToolKit;

    private final pinecone:Client pineconeClient;
    private final embeddings:Client openaiEmbeddings;
    private final string pineconeNamespace;
    private final int topK;
    private final int maxRetrievedWords;
    private final string toolName;
    private final string toolDescription;

    public function init(string toolName, string toolDescription,
            string pineconeServiceUrl, string pineconeKey, string pineconeNamespace,
            string openAiEmbeddingToken, int topK = 3, int maxRetrieveTokens = 1125) returns error? {
        self.pineconeClient = check new ({apiKey: pineconeKey}, serviceUrl = pineconeServiceUrl);
        self.openaiEmbeddings = check new ({auth: {token: openAiEmbeddingToken}});
        self.pineconeNamespace = pineconeNamespace;
        self.topK = topK;
        self.maxRetrievedWords = maxRetrieveTokens;
        self.toolName = toolName;
        self.toolDescription = toolDescription;
    }

    public isolated function getTools() returns agent:ToolConfig[] {
        agent:ToolConfig[] toolConfigs = agent:getToolConfigs([self.retriver]);
        agent:ToolConfig toolConfig = toolConfigs.pop();
        toolConfig.name = self.toolName;
        toolConfig.description = self.toolDescription;
        return [toolConfig];
    }

    public isolated function storeEmbedding(string|string[] content) returns error? {
        string[] values = content is string[] ? content : [content];
        pinecone:Vector[] vectors = [];
        
        foreach var value in values {
            float[] embedding = check self.generateEmbedding(value);
            pinecone:Vector vector = {
                id: uuid:createType1AsString(),
                values: embedding,
                metadata: {"content": value}
            };
            vectors.push(vector);
        }
        

        pinecone:UpsertResponse response = check self.pineconeClient->/vectors/upsert.post({
            vectors,
            namespace: self.pineconeNamespace
        });

        if response.upsertedCount != values.length() {
            return error("Failed to insert embedding vector into Pinecone.");
        }
        io:println("Embedding stored successfully.");
    }

    @agent:Tool
    public isolated function retriver(string query) returns string|error {
        float[] queryEmbedding = check self.generateEmbedding(query);
        pinecone:QueryResponse res = check self.pineconeClient->/query.post({
            namespace: self.pineconeNamespace,
            topK: self.topK,
            vector: queryEmbedding,
            includeMetadata: true
        });

        pinecone:QueryMatch[]? matches = res.matches;
        if matches is () || matches.length() == 0 {
            return error("No information found.");
        }

        string context = "";
        int contextLen = 0;

        foreach pinecone:QueryMatch 'match in matches {
            pinecone:VectorMetadata? metadata = 'match.metadata;
            if metadata is () {
                continue;
            }
            string content = check metadata["content"].ensureType();
            contextLen += self.countWords(content);
            if contextLen > self.maxRetrievedWords {
                break;
            }
            context += "\n* " + content;
        }
        return context;
    }

    private isolated function countWords(string text) returns int =>
        regexp:split(re `\s+`, text).length();

    private isolated function generateEmbedding(string text) returns float[]|error {
        embeddings:CreateEmbeddingResponse res = check self.openaiEmbeddings->/embeddings.post({
            input: text,
            model: "text-embedding-3-small"
        });
        return res.data[0].embedding;
    }
}
