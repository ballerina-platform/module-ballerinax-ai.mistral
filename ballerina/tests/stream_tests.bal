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
isolated function collect(stream<ai:ChatMessageChunk, ai:Error?> chunks)
        returns ai:ChatMessageChunk[]|ai:Error {
    ai:ChatMessageChunk[] collected = [];
    ai:Error? err = from ai:ChatMessageChunk chunk in chunks
        do {
            collected.push(chunk);
        };
    if err is ai:Error {
        return err;
    }
    return collected;
}

# Returns the finish reason of the last chunk that carries one.
isolated function finalFinishReason(ai:ChatMessageChunk[] chunks) returns ai:FinishReason? {
    ai:FinishReason? finishReason = ();
    foreach ai:ChatMessageChunk chunk in chunks {
        ai:FinishReason? reason = chunk.finishReason;
        if reason is ai:FinishReason {
            finishReason = reason;
        }
    }
    return finishReason;
}

@test:Config
function testChatStreamDeliversEveryChunk() returns ai:Error? {
    ModelProvider provider = check streamProvider("text");
    stream<ai:ChatMessageChunk, ai:Error?> chunkStream = check provider->chatAsStream({role: ai:USER, content: "Hi"});
    ai:ChatMessageChunk[] chunks = check collect(chunkStream);

    test:assertEquals(chunks.length(), 3, "the terminal chunk must not be dropped");
    test:assertEquals(chunks[0].content, "Hel");
    test:assertEquals(chunks[1].content, "lo");
    test:assertEquals(chunks[2].content, "!");
    test:assertEquals(chunks[2].finishReason, ai:STOP);
}

@test:Config
function testChatStreamSetsRoleOnEveryChunk() returns ai:Error? {
    ModelProvider provider = check streamProvider("text");
    stream<ai:ChatMessageChunk, ai:Error?> chunkStream = check provider->chatAsStream({role: ai:USER, content: "Hi"});
    ai:ChatMessageChunk[] chunks = check collect(chunkStream);

    test:assertTrue(chunks.length() > 0, "expected at least one chunk");
    foreach ai:ChatMessageChunk chunk in chunks {
        test:assertEquals(chunk.role, ai:ASSISTANT, "expected 'role' to be set on every chunk");
    }
}

@test:Config
function testChatStreamWithUnknownFinishReason() returns ai:Error? {
    ModelProvider provider = check streamProvider("unknownfinish");
    stream<ai:ChatMessageChunk, ai:Error?> chunkStream = check provider->chatAsStream({role: ai:USER, content: "Hi"});
    ai:ChatMessageChunk[] chunks = check collect(chunkStream);

    // An unrecognized reason must degrade to `()`, not drop the chunk.
    test:assertEquals(chunks.length(), 1);
    test:assertEquals(chunks[0].finishReason, ());
}

@test:Config
function testChatStreamWithContentFilterFinishReason() returns ai:Error? {
    ModelProvider provider = check streamProvider("contentfilter");
    stream<ai:ChatMessageChunk, ai:Error?> chunkStream = check provider->chatAsStream({role: ai:USER, content: "Hi"});
    ai:ChatMessageChunk[] chunks = check collect(chunkStream);

    test:assertEquals(chunks.length(), 1);
    test:assertEquals(chunks[0].finishReason, ai:CONTENT_FILTER);
}

@test:Config
function testChatStreamWithReasoningContent() returns ai:Error? {
    ModelProvider provider = check streamProvider("reasoning");
    stream<ai:ChatMessageChunk, ai:Error?> chunkStream = check provider->chatAsStream({role: ai:USER, content: "Hi"});
    ai:ChatMessageChunk[] chunks = check collect(chunkStream);

    test:assertEquals(chunks.length(), 2, "`thinking` fragments must not fail the chunk");
    // Reasoning is surfaced separately from the answer text.
    test:assertEquals(chunks[0].reasoning, "weighing");
    test:assertEquals(chunks[0].content, ());
    test:assertEquals(chunks[1].content, "Answer");
    test:assertEquals(chunks[1].reasoning, ());
}

@test:Config
function testChatStreamWithToolCallFragments() returns ai:Error? {
    ModelProvider provider = check streamProvider("tools");
    stream<ai:ChatMessageChunk, ai:Error?> chunkStream = check provider->chatAsStream({role: ai:USER, content: "Weather?"},
            [{name: "getWeather", description: "Gets the weather", parameters: {"type": "object"}}]);
    ai:ChatMessageChunk[] chunks = check collect(chunkStream);

    test:assertEquals(chunks.length(), 3);
    ai:ToolCallChunk[] first = <ai:ToolCallChunk[]>chunks[0].toolCalls;
    test:assertEquals(first[0].id, "call_1");
    test:assertEquals(first[0]?.name, "getWeather");
    test:assertEquals(chunks[2].finishReason, ai:TOOL_CALLS);

    // Mistral omits `index` on the later fragments of a single tool call; the
    // position in the array must stand in so fragments still correlate.
    string arguments = "";
    foreach ai:ChatMessageChunk chunk in chunks {
        ai:ToolCallChunk[]? toolCalls = chunk.toolCalls;
        if toolCalls is ai:ToolCallChunk[] {
            test:assertEquals(toolCalls[0].index, 0);
            arguments += toolCalls[0]?.arguments ?: "";
        }
    }
    test:assertEquals(arguments, string `{"city":"CMB"}`);
}

@test:Config
function testChatStreamFailsOnAbortedGeneration() returns ai:Error? {
    ModelProvider provider = check streamProvider("aborted");
    stream<ai:ChatMessageChunk, ai:Error?> chunkStream = check provider->chatAsStream({role: ai:USER, content: "Hi"});
    ai:ChatMessageChunk[]|ai:Error result = collect(chunkStream);

    // A truncated answer must not be reported as a clean end of stream.
    if result is ai:ChatMessageChunk[] {
        test:assertFail("expected the aborted generation to fail the stream");
    }
    test:assertTrue(result is ai:LlmError);
    test:assertEquals(result.message(),
            "The model stopped generating due to an error before completing the response");
}

@test:Config
function testChatStreamFailsOnMalformedChunk() returns ai:Error? {
    ModelProvider provider = check streamProvider("malformed");
    stream<ai:ChatMessageChunk, ai:Error?> chunkStream = check provider->chatAsStream({role: ai:USER, content: "Hi"});
    ai:ChatMessageChunk[]|ai:Error result = collect(chunkStream);

    if result is ai:ChatMessageChunk[] {
        test:assertFail("expected the malformed chunk to fail the stream");
    }
    test:assertTrue(result is ai:LlmInvalidResponseError);
    test:assertTrue(result.message().startsWith(
            "Invalid or malformed chunk received from the model while streaming:"), result.message());
}

@test:Config
function testChatStreamSurfacesErrorResponse() returns ai:Error? {
    ModelProvider provider = check streamProvider("ratelimited");
    stream<ai:ChatMessageChunk, ai:Error?>|ai:Error result =
        provider->chatAsStream({role: ai:USER, content: "Hi"});

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
    stream<ai:ChatMessageChunk, ai:Error?>|ai:Error result =
        provider->chatAsStream({role: ai:USER, content: "Hi"});

    if result !is ai:Error {
        test:assertFail("expected a non-SSE response to surface as an error");
    }
    test:assertTrue(result is ai:LlmInvalidResponseError);
}

@test:Config
function testGenerateAsStreamYieldsAnswerText() returns ai:Error? {
    ModelProvider provider = check streamProvider("text");
    stream<string, ai:Error?> fragments = check provider->generateAsStream(`Say hello`);

    string answer = "";
    check from string fragment in fragments
        do {
            answer += fragment;
        };
    test:assertEquals(answer, "Hello!");
}

@test:Config
function testGenerateAsStreamSkipsReasoningFragments() returns ai:Error? {
    ModelProvider provider = check streamProvider("reasoning");
    stream<string, ai:Error?> fragments = check provider->generateAsStream(`Think`);

    string answer = "";
    check from string fragment in fragments
        do {
            answer += fragment;
        };
    // Only the answer text is streamed; the chain-of-thought is not.
    test:assertEquals(answer, "Answer");
}

@test:Config
function testGenerateAsStreamSurfacesConnectionError() returns ai:Error? {
    ModelProvider provider = check streamProvider("ratelimited");
    stream<string, ai:Error?>|ai:Error result = provider->generateAsStream(`Say hello`);

    if result !is ai:Error {
        test:assertFail("expected the 429 response to surface as an error");
    }
    test:assertTrue(result is ai:LlmConnectionError);
}
