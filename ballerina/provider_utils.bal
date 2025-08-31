// Copyright (c) 2025 WSO2 LLC (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/ai;
import ballerina/constraint;
import ballerina/lang.array;
import ballerinax/mistral;
import ballerina/lang.runtime;

type ResponseSchema record {|
    map<json> schema;
    boolean isOriginallyJsonObject = true;
|};

type DocumentContentPart mistral:TextChunk|mistral:ImageURLChunk|mistral:DocumentURLChunk;

const JSON_CONVERSION_ERROR = "FromJsonStringError";
const CONVERSION_ERROR = "ConversionError";
const ERROR_MESSAGE = "Error occurred while attempting to parse the response from the " +
    "LLM as the expected type. Retrying and/or validating the prompt could fix the response.";
const RESULT = "result";
const GET_RESULTS_TOOL = "getResults";
const FUNCTION = "function";
const NO_RELEVANT_RESPONSE_FROM_THE_LLM = "No relevant response from the LLM";

isolated function generateJsonObjectSchema(map<json> schema) returns ResponseSchema {
    string[] supportedMetaDataFields = ["$schema", "$id", "$anchor", "$comment", "title", "description"];

    if schema["type"] == "object" {
        return {schema};
    }

    map<json> updatedSchema = map from var [key, value] in schema.entries()
        where supportedMetaDataFields.indexOf(key) is int
        select [key, value];

    updatedSchema["type"] = "object";
    map<json> content = map from var [key, value] in schema.entries()
        where supportedMetaDataFields.indexOf(key) !is int
        select [key, value];

    updatedSchema["properties"] = {[RESULT]: content};

    return {schema: updatedSchema, isOriginallyJsonObject: false};
}

isolated function parseResponseAsType(string resp,
        typedesc<anydata> expectedResponseTypedesc, boolean isOriginallyJsonObject) returns anydata|error {
    if !isOriginallyJsonObject {
        map<json> respContent = check resp.fromJsonStringWithType();
        anydata|error result = trap respContent[RESULT].fromJsonWithType(expectedResponseTypedesc);
        if result is error {
            return handleParseResponseError(result);
        }
        return result;
    }

    anydata|error result = resp.fromJsonStringWithType(expectedResponseTypedesc);
    if result is error {
        return handleParseResponseError(result);
    }
    return result;
}

isolated function getExpectedResponseSchema(typedesc<anydata> expectedResponseTypedesc) returns ResponseSchema|ai:Error {
    // Restricted at compile-time for now.
    typedesc<json> td = checkpanic expectedResponseTypedesc.ensureType();
    return generateJsonObjectSchema(check generateJsonSchemaForTypedescAsJson(td));
}

isolated function generateChatCreationContent(ai:Prompt prompt)
                        returns DocumentContentPart[]|ai:Error {
    string[] & readonly strings = prompt.strings;
    anydata[] insertions = prompt.insertions;
    DocumentContentPart[] contentParts = [];
    string accumulatedTextContent = "";

    if strings.length() > 0 {
        accumulatedTextContent += strings[0];
    }

    foreach int i in 0 ..< insertions.length() {
        anydata insertion = insertions[i];
        string str = strings[i + 1];

        if insertion is ai:Document {
            addTextContentPart(buildTextContentPart(accumulatedTextContent), contentParts);
            accumulatedTextContent = "";
            check addDocumentContentPart(insertion, contentParts);
        } else if insertion is ai:Document[] {
            addTextContentPart(buildTextContentPart(accumulatedTextContent), contentParts);
            accumulatedTextContent = "";
            foreach ai:Document doc in insertion {
                check addDocumentContentPart(doc, contentParts);
            }
        } else {
            accumulatedTextContent += insertion.toString();
        }
        accumulatedTextContent += str;
    }

    addTextContentPart(buildTextContentPart(accumulatedTextContent), contentParts);
    return contentParts;
}

isolated function addDocumentContentPart(ai:Document doc, DocumentContentPart[] contentParts) returns ai:Error? {
    if doc is ai:TextDocument {
        return addTextContentPart(buildTextContentPart(doc.content), contentParts);
    } else if doc is ai:ImageDocument {
        return contentParts.push(check buildImageContentPart(doc));
    } else if doc is ai:FileDocument {
        return contentParts.push(check buildFileContentPart(doc));
    }
    return error("Only text, image and file documents are supported.");
}

isolated function addTextContentPart(mistral:TextChunk? contentPart, DocumentContentPart[] contentParts) {
    if contentPart is mistral:TextChunk {
        return contentParts.push(contentPart);
    }
}

isolated function buildTextContentPart(string content) returns mistral:TextChunk? {
    if content.length() == 0 {
        return;
    }

    return {
        'type: "text",
        text: content
    };
}

isolated function buildImageContentPart(ai:ImageDocument doc) returns mistral:ImageURLChunk|ai:Error =>
    {
    imageUrl: {
        url: check buildImageUrl(doc.content, doc.metadata?.mimeType)
    }
};

isolated function buildFileContentPart(ai:FileDocument doc) returns mistral:DocumentURLChunk|ai:Error {
    byte[]|ai:Url|ai:FileId content = doc.content;
    if content !is ai:Url {
        return error("Currently, only URL based file documents are supported.");
    }

    ai:Url|constraint:Error validationRes = constraint:validate(content);
    if validationRes is error {
        return error(validationRes.message(), validationRes.cause());
    }

    string? fileName = doc.metadata?.fileName;
    return fileName is () ? {
            documentUrl: content
        } : {
            documentUrl: content,
            documentName: fileName
        };
}

isolated function buildImageUrl(ai:Url|byte[] content, string? mimeType) returns string|ai:Error {
    if content is ai:Url {
        ai:Url|constraint:Error validationRes = constraint:validate(content);
        if validationRes is error {
            return error(validationRes.message(), validationRes.cause());
        }
        return content;
    }

    if mimeType is () {
        return error("Please specify the mimeType for the image document.");
    }

    return string `data:${mimeType};base64,${check getBase64EncodedString(content)}`;
}

isolated function getBase64EncodedString(byte[] content) returns string|ai:Error {
    string|error binaryContent = array:toBase64(content);
    if binaryContent is error {
        return error("Failed to convert byte array to string: " + binaryContent.message() + ", " +
                        binaryContent.detail().toBalString());
    }
    return binaryContent;
}

isolated function handleParseResponseError(error chatResponseError) returns error {
    string msg = chatResponseError.message();
    if msg.includes(JSON_CONVERSION_ERROR) || msg.includes(CONVERSION_ERROR) {
        return error(ERROR_MESSAGE, chatResponseError);
    }
    return chatResponseError;
}

isolated function getGetResultsToolChoice() returns mistral:ToolChoice => {
    'type: FUNCTION,
    'function: {
        name: GET_RESULTS_TOOL
    }
};

isolated function getGetResultsTool(map<json> parameters) returns mistral:Tool[]|error =>
    [
    {
        'function: {
            name: GET_RESULTS_TOOL,
            parameters: check parameters.cloneWithType(),
            strict: false,
            description: "Tool to call with the resp onse from a large language model (LLM) for a user prompt."
        }
    }
];
isolated function generateLlmResponse(mistral:Client llmClient, int maxTokens, MISTRAL_AI_MODEL_NAMES modelType,
        decimal temperature, ai:GeneratorConfig generatorConfig, 
        ai:Prompt prompt, typedesc<json> expectedResponseTypedesc) returns anydata|ai:Error {
    
    DocumentContentPart[] chatContent = check generateChatCreationContent(prompt);
    ResponseSchema responseSchema = check getExpectedResponseSchema(expectedResponseTypedesc);
    mistral:Tool[]|error tools = getGetResultsTool(responseSchema.schema);
    if tools is error {
        return error("Error while generating the tool: " + tools.message());
    }

    mistral:ChatCompletionRequest request = {
        messages: [
            {
                role: "user",
                content: chatContent
            }
        ],
        model: modelType,
        tools,
        temperature,
        maxTokens,
        toolChoice: getGetResultsToolChoice()
    };
    
    [int, decimal] [count, interval] = check getRetryConfigValues(generatorConfig);

    return getLlmResponse(llmClient, request, expectedResponseTypedesc, responseSchema.isOriginallyJsonObject, count, interval);
}

isolated function getLlmResponse(mistral:Client llmClient, mistral:ChatCompletionRequest request,
        typedesc<anydata> expectedResponseTypedesc, boolean isOriginallyJsonObject, int retryCount, decimal retryInterval) returns anydata|ai:Error {
    
    mistral:ChatCompletionResponse|error response = llmClient->/chat/completions.post(request);
    if response is error {
        return error ai:LlmConnectionError("Error while connecting to the model", response);
    }

    mistral:ChatCompletionChoice[]? choices = response.choices;
    if choices is () || choices.length() == 0 {
        return error ai:LlmInvalidResponseError("Empty response from the model when using function call API");
    }
    mistral:AssistantMessage message = choices[0].message;

    mistral:ToolCall[]? toolCalls = message?.toolCalls;
    if toolCalls is () || toolCalls.length() == 0 {
        return error(NO_RELEVANT_RESPONSE_FROM_THE_LLM);
    }

    mistral:ToolCall tool = toolCalls[0];
    string|record {} toolArguments = tool.'function.arguments;

    if toolArguments is "" {
        return error(NO_RELEVANT_RESPONSE_FROM_THE_LLM);
    }
    
    mistral:AgentsCompletionRequestMessages[] history = request.messages;
    history.push(message);

    anydata|error result = handleResponseWithExpectedType(toolArguments.toString(), isOriginallyJsonObject,
                    expectedResponseTypedesc);
    
    if result is error && retryCount > 0 {
        string|error repairMessage = getRepairMessage(result, tool.id, tool.'function.name);
        if repairMessage is error {
            return error("Failed to generate a valid response: " + repairMessage.message());
        }

        history.push({role: "user", content: repairMessage});
        runtime:sleep(retryInterval);
        return getLlmResponse(llmClient, request, expectedResponseTypedesc, isOriginallyJsonObject, retryCount - 1, retryInterval);
    }

    if result is anydata {
        return result;
    }

    return error ai:LlmInvalidGenerationError(string `Invalid value returned from the LLM Client, expected: '${
            expectedResponseTypedesc.toBalString()}', found '${result.toBalString()}'`);
}

isolated function handleResponseWithExpectedType(string arguments, boolean isOriginallyJsonObject,
                                typedesc<anydata> expectedResponseTypedesc) returns anydata|error {
    anydata res = check parseResponseAsType(arguments, expectedResponseTypedesc, isOriginallyJsonObject);
    return res.ensureType(expectedResponseTypedesc);
}

isolated function getRepairMessage(error e, string toolId, string functionName) returns string|error {
    error? cause = e.cause();
    if cause is () {
        return e;
    }

    return string `The tool call with ${toolId != "null" ? string `ID '${toolId}' for the ` : ""}function '${functionName}' failed.
        Error: ${cause.toString()}
        You must correct the function arguments based on this error and respond with a valid tool call.`;
}

isolated function getRetryConfigValues(ai:GeneratorConfig generatorConfig) returns [int, decimal]|ai:Error {
    ai:RetryConfig? retryConfig = generatorConfig.retryConfig;
    if retryConfig != () {
        int count = retryConfig.count;
        decimal? interval = retryConfig.interval;

        if count < 0 {
            return error("Invalid retry count: " + count.toString());
        }
        if interval < 0d {
            return error("Invalid retry interval: " + interval.toString());
        }

        return [count, interval ?: 0d];
    }
    return [0, 0d];
}
