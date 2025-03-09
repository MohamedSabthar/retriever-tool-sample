public type OllamaResponse record {
    string model;
    OllamaMessage message;
};

public type OllamaMessage record {
    string role;
    string content?;
    OllamaToolCall[] tool_calls?;
};

public type OllamaToolCall record {
    OllamaFunction 'function;
};

public type OllamaFunction record {
    string name;
    map<json> arguments;
};