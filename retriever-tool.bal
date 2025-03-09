import ballerina/io;
import ballerina/uuid;
import ballerinax/ai.agent;
import ballerinax/openai.embeddings;
import ballerinax/pinecone.vector as pinecone;

public type PineconeConfig record {|
    string serviceUrl;
    string apiKey;
    string namespace;
    int topK = 3;
|};

public type OpenAiEmbeddingModelConfig record {|
    string apiKey;
    string modelName;
|};

public isolated class Retriever {
    *agent:BaseToolKit;

    private final pinecone:Client pineconeClient;
    private final embeddings:Client openaiEmbeddings;
    private final readonly & PineconeConfig pineconeConfig;
    private final readonly & OpenAiEmbeddingModelConfig openAiEmbeddingModelConfig;

    public function init(PineconeConfig pineconeConfig, OpenAiEmbeddingModelConfig openAiEmbeddingModelConfig) returns error? {
        self.pineconeConfig = pineconeConfig.cloneReadOnly();
        self.openAiEmbeddingModelConfig = openAiEmbeddingModelConfig.cloneReadOnly();
        self.pineconeClient = check new ({apiKey: self.pineconeConfig.apiKey}, serviceUrl = self.pineconeConfig.serviceUrl);
        self.openaiEmbeddings = check new ({auth: {token: self.openAiEmbeddingModelConfig.apiKey}});
    }

    public isolated function getTools() returns agent:ToolConfig[] {
        return agent:getToolConfigs([self.retriver]);
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
            namespace: self.pineconeConfig.namespace
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
            namespace: self.pineconeConfig.namespace,
            topK: self.pineconeConfig.topK,
            vector: queryEmbedding,
            includeMetadata: true
        });

        pinecone:QueryMatch[]? matches = res.matches;
        if matches is () || matches.length() == 0 {
            return error("No information found.");
        }

        string context = "";
        foreach pinecone:QueryMatch 'match in matches {
            pinecone:VectorMetadata? metadata = 'match.metadata;
            if metadata is () {
                continue;
            }
            string content = check metadata["content"].ensureType();
            context += "\n" + content;
        }
        return context;
    }

    private isolated function generateEmbedding(string text) returns float[]|error {
        embeddings:CreateEmbeddingResponse res = check self.openaiEmbeddings->/embeddings.post({
            input: text,
            model: self.openAiEmbeddingModelConfig.modelName
        });
        return res.data[0].embedding;
    }
}
