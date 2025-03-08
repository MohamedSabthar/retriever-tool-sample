```cURL
curl --location 'http://localhost:8090/chatMessage' \
--header 'Content-Type: application/json' \
--data '{
    "sessionId": "1",
    "message": "What is ballerina?"
}'
```