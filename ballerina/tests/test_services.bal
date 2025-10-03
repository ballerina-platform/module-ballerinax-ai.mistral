// Copyright (c) 2025 WSO2 LLC. (http://www.wso2.org).
//
// WSO2 Inc. licenses this file to you under the Apache License,
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

import ballerina/http;
import ballerina/test;
import ballerinax/mistral;

service /llm on new http:Listener(8080) {
    private map<int> retryCountMap = {};

    resource function post chat/completions(@http:Payload json payload) returns mistral:ChatCompletionResponse|error {
        [string, json[]] [initialText, _] = check validateInitialMistralPayload(payload);
        return getTestServiceResponse(initialText, 0);
    }

    resource function post retry\-test/chat/completions(@http:Payload json payload) returns mistral:ChatCompletionResponse|error {
        json[] messages = check payload.messages.ensureType();
        if messages.length() == 0 {
            test:assertFail("Payload must contain messages");
        }

        json[] content = check messages[0].content.ensureType();
        mistral:TextChunk initialTextContent = check content[0].fromJsonWithType();
        string initialText = initialTextContent.text;

        int index;
        lock {
            index = updateRetryCountMap(initialText, self.retryCountMap);
        }

        check assertContentParts(messages, initialText, index);
        return getTestServiceResponse(initialText, index);
    }
}

isolated function validateInitialMistralPayload(json payload)
        returns [string, json[]]|error {
    test:assertEquals(payload.model, MINISTRAL_8B_2410);
    test:assertEquals(payload.temperature, 0.1d);
    test:assertEquals(payload.max_tokens, 100);

    json[] messages = check payload.messages.ensureType();
    map<json> message = check (messages[0]).fromJsonWithType();
    json[] content = check message.content.ensureType();
    mistral:TextChunk initialTextContent = check content[0].fromJsonWithType();
    string initialText = initialTextContent.text;
        
    test:assertEquals(messages[0].content, check getExpectedContentParts(initialText));

    json[]? tools = check payload?.tools.ensureType();
    if tools is () || tools.length() == 0 {
        test:assertFail("No tools in the payload");
    }

    mistral:Tool tool = check tools[0].fromJsonWithType();
    record {} parameters = tool.'function.parameters;
    if parameters == {} {
        test:assertFail("No parameters in the expected tool in the test with content: " + initialText);
    }
    test:assertEquals(tool.'function.parameters, getExpectedParameterSchema(initialText));
    
    return [initialText, messages];
}

isolated function assertContentParts(json[] messages, 
        string initialText, int index) returns error? {
    if index >= messages.length() {
        test:assertFail(string `Expected at least ${index + 1} message(s) in the payload`);
    }

    // Test input messages where the role is 'user'.
    json message = messages[index * 2];
    json|error? content = message.content.ensureType();

    if content is () {
        test:assertFail("Expected content in the payload");
    }

    if index == 0 {
        test:assertEquals(content, check getExpectedContentParts(initialText),
            string `Prompt assertion failed for prompt starting with '${initialText}'`);
        return;
    }

    if index == 1 {
        test:assertEquals(content, check getExpectedContentPartsForFirstRetryCall(initialText),
            string `Prompt assertion failed for prompt starting with '${initialText}' 
                on first attempt of the retry`);
        return;
    }

    test:assertEquals(content,check getExpectedContentPartsForSecondRetryCall(initialText),
            string `Prompt assertion failed for prompt starting with '${initialText}' on 
                second attempt of the retry`);
}
