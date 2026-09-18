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

# Mock Mistral AI chat completions endpoint for the streaming tests. Each resource
# replays a fixed Server-Sent Event script so the wire shapes the provider must
# tolerate - unknown finish reasons, `thinking` fragments, tool-call fragments,
# malformed payloads, non-SSE error responses - can be exercised deterministically.
service /llm on new http:Listener(8081) {

    # A plain text completion: two content deltas, then a terminal chunk carrying
    # `finish_reason` and `usage`.
    resource function post text/chat/completions(@http:Payload json payload) returns http:Response {
        return sseResponse([
            chunkData({"role": "assistant", "content": "Hel"}, ()),
            chunkData({"content": "lo"}, ()),
            string `{"id":"c1","model":"m","choices":[{"index":0,"delta":{"content":"!"},` +
                string `"finish_reason":"stop"}],"usage":{"prompt_tokens":7,"completion_tokens":3,` +
                string `"total_tokens":10}}`,
            DONE_SENTINEL
        ]);
    }

    # A finish reason outside the set this module knows about. The chunk must still
    # be delivered - only the `finishReason` degrades to `()`.
    resource function post unknownfinish/chat/completions() returns http:Response {
        return sseResponse([
            string `{"id":"c1","model":"m","choices":[{"index":0,"delta":{"content":"hi"},` +
                string `"finish_reason":"some_future_reason"}],"usage":{"prompt_tokens":1,` +
                string `"completion_tokens":1,"total_tokens":2}}`,
            DONE_SENTINEL
        ]);
    }

    # `content_filter`, which Mistral does not document but `ai:FinishReason` models.
    resource function post contentfilter/chat/completions() returns http:Response {
        return sseResponse([
            string `{"id":"c1","model":"m","choices":[{"index":0,"delta":{"content":"hi"},` +
                string `"finish_reason":"content_filter"}]}`,
            DONE_SENTINEL
        ]);
    }

    # A reasoning model (`magistral-*`) streaming `thinking` fragments alongside text.
    resource function post reasoning/chat/completions() returns http:Response {
        return sseResponse([
            string `{"id":"c1","model":"magistral-small-latest","choices":[{"index":0,"delta":` +
                string `{"content":[{"type":"thinking","thinking":[{"type":"text","text":"weighing"}]}]}}]}`,
            string `{"id":"c1","model":"magistral-small-latest","choices":[{"index":0,"delta":` +
                string `{"content":[{"type":"text","text":"Answer"}]}}]}`,
            DONE_SENTINEL
        ]);
    }

    # Tool calls streamed as fragments: the name on the first chunk, argument
    # fragments after it. The second fragment omits `index`, as Mistral does for a
    # single tool call.
    resource function post tools/chat/completions() returns http:Response {
        return sseResponse([
            chunkData({
                "tool_calls": [
                    {
                        "index": 0,
                        "id": "call_1",
                        "type": "function",
                        "function": {"name": "getWeather", "arguments": ""}
                    }
                ]
            }, ()),
            chunkData({"tool_calls": [{"function": {"arguments": string `{"city":`}}]}, ()),
            chunkData({"tool_calls": [{"function": {"arguments": string `"CMB"}`}}]}, "tool_calls"),
            DONE_SENTINEL
        ]);
    }

    # The model aborts mid-generation.
    resource function post aborted/chat/completions() returns http:Response {
        return sseResponse([
            chunkData({"content": "partial"}, ()),
            string `{"id":"c1","model":"m","choices":[{"index":0,"delta":{},"finish_reason":"error"}]}`,
            DONE_SENTINEL
        ]);
    }

    # A payload that is not valid JSON, in the middle of an otherwise fine stream.
    resource function post malformed/chat/completions() returns http:Response {
        return sseResponse([
            chunkData({"content": "ok"}, ()),
            "{not json}",
            DONE_SENTINEL
        ]);
    }

    # A non-2xx response, which arrives as a JSON error body rather than an SSE stream.
    resource function post ratelimited/chat/completions() returns http:Response {
        http:Response response = new;
        response.statusCode = http:STATUS_TOO_MANY_REQUESTS;
        response.setJsonPayload({message: "Requests rate limit exceeded", request_id: "req-1"});
        return response;
    }

    # A 200 response that is not an event stream at all.
    resource function post notastream/chat/completions() returns http:Response {
        http:Response response = new;
        response.setJsonPayload({id: "c1", choices: []});
        return response;
    }
}

# Builds a chunk payload with a single choice carrying the given delta.
#
# + delta - The delta object of the choice
# + finishReason - The finish reason, or `()` for a non-terminal chunk
# + return - The serialized chunk
isolated function chunkData(map<json> delta, string? finishReason) returns string {
    json chunk = {
        id: "c1",
        model: "m",
        choices: [{index: 0, delta, finish_reason: finishReason}]
    };
    return chunk.toJsonString();
}

# Wraps the given `data:` payloads in a Server-Sent Event response.
#
# + payloads - The payload of each event, in order
# + return - The mock SSE response
isolated function sseResponse(string[] payloads) returns http:Response {
    http:Response response = new;
    string body = "";
    foreach string payload in payloads {
        body += string `data: ${payload}${"\n\n"}`;
    }
    response.setTextPayload(body, "text/event-stream");
    return response;
}
