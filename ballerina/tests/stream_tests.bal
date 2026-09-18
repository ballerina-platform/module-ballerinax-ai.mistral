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

import ballerina/ai;
import ballerina/test;

const STREAM_SERVICE_URL = "http://localhost:8081/llm";

isolated function streamProvider(string path) returns ModelProvider|ai:Error =>
    new (API_KEY, MINISTRAL_8B_2410, string `${STREAM_SERVICE_URL}/${path}`, maxTokens = 100, temperature = 0.1);

# Collects a chunk stream into a list, so assertions can be made over the whole
# sequence rather than one chunk at a time.
isolated function collect(stream<ai:ChatCompletionChunk, ai:Error?> chunks)
        returns ai:ChatCompletionChunk[]|ai:Error {
    ai:ChatCompletionChunk[] collected = [];
    ai:Error? err = from ai:ChatCompletionChunk chunk in chunks
        do {
            collected.push(chunk);
        };
    if err is ai:Error {
        return err;
    }
    return collected;
}

@test:Config
function testChatStreamDeliversEveryChunk() returns ai:Error? {
    ModelProvider provider = check streamProvider("text");
    stream<ai:ChatCompletionChunk, ai:Error?> chunkStream = check provider->chatStream({role: ai:USER, content: "Hi"});
    ai:ChatCompletionChunk[] chunks = check collect(chunkStream);

    test:assertEquals(chunks.length(), 3, "the terminal chunk must not be dropped");
    test:assertEquals(chunks[0].choices[0].delta.role, ai:ASSISTANT);
    test:assertEquals(chunks[0].choices[0].delta.content, "Hel");
    test:assertEquals(chunks[1].choices[0].delta.content, "lo");
    test:assertEquals(chunks[2].choices[0].finishReason, ai:STOP);
    test:assertEquals(chunks[2].usage, <ai:CompletionTokenUsage>{
        promptTokens: 7,
        completionTokens: 3,
        totalTokens: 10
    });
}

@test:Config
function testChatStreamWithUnknownFinishReason() returns ai:Error? {
    ModelProvider provider = check streamProvider("unknownfinish");
    stream<ai:ChatCompletionChunk, ai:Error?> chunkStream = check provider->chatStream({role: ai:USER, content: "Hi"});
    ai:ChatCompletionChunk[] chunks = check collect(chunkStream);

    // An unrecognized reason must degrade to `()`, not drop the chunk and its usage.
    test:assertEquals(chunks.length(), 1);
    test:assertEquals(chunks[0].choices[0].finishReason, ());
    test:assertEquals(chunks[0].usage?.totalTokens, 2);
}

@test:Config
function testChatStreamWithContentFilterFinishReason() returns ai:Error? {
    ModelProvider provider = check streamProvider("contentfilter");
    stream<ai:ChatCompletionChunk, ai:Error?> chunkStream = check provider->chatStream({role: ai:USER, content: "Hi"});
    ai:ChatCompletionChunk[] chunks = check collect(chunkStream);

    test:assertEquals(chunks.length(), 1);
    test:assertEquals(chunks[0].choices[0].finishReason, ai:CONTENT_FILTER);
}

@test:Config
function testChatStreamWithReasoningContent() returns ai:Error? {
    ModelProvider provider = check streamProvider("reasoning");
    stream<ai:ChatCompletionChunk, ai:Error?> chunkStream = check provider->chatStream({role: ai:USER, content: "Hi"});
    ai:ChatCompletionChunk[] chunks = check collect(chunkStream);

    test:assertEquals(chunks.length(), 2, "`thinking` fragments must not fail the chunk");
    // Reasoning is surfaced separately from the answer text.
    test:assertEquals(chunks[0].choices[0].delta.reasoning, "weighing");
    test:assertEquals(chunks[0].choices[0].delta.content, ());
    test:assertEquals(chunks[1].choices[0].delta.content, "Answer");
    test:assertEquals(chunks[1].choices[0].delta.reasoning, ());
}

@test:Config
function testChatStreamWithToolCallFragments() returns ai:Error? {
    ModelProvider provider = check streamProvider("tools");
    stream<ai:ChatCompletionChunk, ai:Error?> chunkStream = check provider->chatStream({role: ai:USER, content: "Weather?"},
            [{name: "getWeather", description: "Gets the weather", parameters: {"type": "object"}}]);
    ai:ChatCompletionChunk[] chunks = check collect(chunkStream);

    test:assertEquals(chunks.length(), 3);
    ai:ToolCallChunk[] first = <ai:ToolCallChunk[]>chunks[0].choices[0].delta.toolCalls;
    test:assertEquals(first[0].id, "call_1");
    test:assertEquals(first[0]?.'function?.name, "getWeather");

    // Mistral omits `index` on the later fragments of a single tool call; the
    // position in the array must stand in so fragments still correlate.
    string arguments = "";
    foreach ai:ChatCompletionChunk chunk in chunks {
        ai:ToolCallChunk[]? toolCalls = chunk.choices[0].delta.toolCalls;
        if toolCalls is ai:ToolCallChunk[] {
            test:assertEquals(toolCalls[0].index, 0);
            arguments += toolCalls[0]?.'function?.arguments ?: "";
        }
    }
    test:assertEquals(arguments, string `{"city":"CMB"}`);
}

@test:Config
function testChatStreamFailsOnAbortedGeneration() returns ai:Error? {
    ModelProvider provider = check streamProvider("aborted");
    stream<ai:ChatCompletionChunk, ai:Error?> chunkStream = check provider->chatStream({role: ai:USER, content: "Hi"});
    ai:ChatCompletionChunk[]|ai:Error result = collect(chunkStream);

    // A truncated answer must not be reported as a clean end of stream.
    if result is ai:ChatCompletionChunk[] {
        test:assertFail("expected the aborted generation to fail the stream");
    }
    test:assertTrue(result is ai:LlmError);
    test:assertEquals(result.message(),
            "The model stopped generating due to an error before completing the response");
}

@test:Config
function testChatStreamFailsOnMalformedChunk() returns ai:Error? {
    ModelProvider provider = check streamProvider("malformed");
    stream<ai:ChatCompletionChunk, ai:Error?> chunkStream = check provider->chatStream({role: ai:USER, content: "Hi"});
    ai:ChatCompletionChunk[]|ai:Error result = collect(chunkStream);

    if result is ai:ChatCompletionChunk[] {
        test:assertFail("expected the malformed chunk to fail the stream");
    }
    test:assertTrue(result is ai:LlmInvalidResponseError);
    test:assertTrue(result.message().startsWith(
            "Invalid or malformed chunk received from the model while streaming:"), result.message());
}

@test:Config
function testChatStreamSurfacesErrorResponse() returns ai:Error? {
    ModelProvider provider = check streamProvider("ratelimited");
    stream<ai:ChatCompletionChunk, ai:Error?>|ai:Error result =
        provider->chatStream({role: ai:USER, content: "Hi"});

    if result !is ai:Error {
        test:assertFail("expected the 429 response to surface as an error");
    }
    test:assertTrue(result is ai:LlmConnectionError);
    test:assertTrue(result.message().includes("HTTP 429"), result.message());
    test:assertTrue(result.message().includes("Requests rate limit exceeded"), result.message());
}

@test:Config
function testChatStreamRejectsNonSseResponse() returns ai:Error? {
    ModelProvider provider = check streamProvider("notastream");
    stream<ai:ChatCompletionChunk, ai:Error?>|ai:Error result =
        provider->chatStream({role: ai:USER, content: "Hi"});

    if result !is ai:Error {
        test:assertFail("expected a non-SSE response to surface as an error");
    }
    test:assertTrue(result is ai:LlmInvalidResponseError);
}

@test:Config
function testGenerateStreamYieldsAnswerText() returns ai:Error? {
    ModelProvider provider = check streamProvider("text");
    stream<string, ai:Error?> fragments = check provider->generateStream(`Say hello`);

    string answer = "";
    check from string fragment in fragments
        do {
            answer += fragment;
        };
    test:assertEquals(answer, "Hello!");
}

@test:Config
function testGenerateStreamSkipsReasoningFragments() returns ai:Error? {
    ModelProvider provider = check streamProvider("reasoning");
    stream<string, ai:Error?> fragments = check provider->generateStream(`Think`);

    string answer = "";
    check from string fragment in fragments
        do {
            answer += fragment;
        };
    // Only the answer text is streamed; the chain-of-thought is not.
    test:assertEquals(answer, "Answer");
}

@test:Config
function testGenerateStreamRejectsNonStringType() returns ai:Error? {
    ModelProvider provider = check streamProvider("text");
    stream<int, ai:Error?>|ai:Error result = provider->generateStream(`Rate this out of 10`);

    if result !is ai:Error {
        test:assertFail("expected a non-string expected type to be rejected");
    }
    test:assertEquals(result.message(), "This data type is not supported for streaming. " +
            "'generateStream' supports only 'string'; use 'generate' for structured types.");
}
