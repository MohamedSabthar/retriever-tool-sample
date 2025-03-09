public type OllamaResponse record {
    string model;
    OllamaMessage message;
};

public type OllamaMessage record {
    string role;
    string content?;
    OllamaToolCalls[] tool_calls?;
};

public type OllamaToolCalls record {
    OllamaFunction 'function;
};

public type OllamaFunction record {
    string name;
    map<json> arguments;
};