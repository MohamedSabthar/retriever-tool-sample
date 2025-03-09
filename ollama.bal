import ballerina/http;
import ballerinax/ai.agent;

public isolated client class OllamaModel {
    *agent:Model;
    private final http:Client ollamaClient;
    private final string modelType;

    public isolated function init(string serviceUrl, string modelType) returns error? {
        self.ollamaClient = check new (serviceUrl);
        self.modelType = modelType;
    }

    isolated remote function chat(agent:ChatMessage[] messages, agent:ChatCompletionFunctions[] tools, string? stop)
        returns agent:ChatAssistantMessage[]|agent:LlmError {
        do {
            json[] transformedMessages = messages.'map(isolated function(agent:ChatMessage message) returns json {
                if message is agent:ChatFunctionMessage {
                    return {role: "tool", content: message?.content};
                }
                return message;
            });
            json request = {
                model: self.modelType,
                messages: transformedMessages,
                'stream: false,
                tools: tools.'map(tool => {'type: "function", 'function: tool})
            };

            OllamaResponse response = check self.ollamaClient->/api/chat.post(request);
            OllamaToolCalls[]? toolCalls = response.message?.tool_calls;
            if toolCalls is OllamaToolCalls[] {
                return [
                    {
                        role: agent:ASSISTANT,
                        function_call: {
                            name: toolCalls[0].'function.name,
                            arguments: toolCalls[0].'function.arguments.toJsonString()
                        }
                    }
                ];
            }
            return [
                {
                    role: agent:ASSISTANT,
                    content: response.message.content
                }
            ];

        } on fail error e {
            return error agent:LlmError("Failed to call chat endpoint", e)
            ;
        }
    }
}

