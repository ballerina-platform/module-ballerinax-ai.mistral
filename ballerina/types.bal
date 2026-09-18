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
import ballerina/http;
import ballerinax/mistral;

# Configurations for controlling the behaviours when communicating with a remote HTTP endpoint.
@display {label: "Connection Configuration"}
public type ConnectionConfig record {|

    # The HTTP version understood by the client
    @display {label: "HTTP Version"}
    http:HttpVersion httpVersion = http:HTTP_2_0;

    # Configurations related to HTTP/1.x protocol
    @display {label: "HTTP1 Settings"}
    http:ClientHttp1Settings http1Settings?;

    # Configurations related to HTTP/2 protocol
    @display {label: "HTTP2 Settings"}
    http:ClientHttp2Settings http2Settings?;

    # The maximum time to wait (in seconds) for a response before closing the connection
    @display {label: "Timeout"}
    decimal timeout = 60;

    # The choice of setting `forwarded`/`x-forwarded` header
    @display {label: "Forwarded"}
    string forwarded = "disable";

    # Configurations associated with request pooling
    @display {label: "Pool Configuration"}
    http:PoolConfiguration poolConfig?;

    # HTTP caching related configurations
    @display {label: "Cache Configuration"}
    http:CacheConfig cache?;

    # Specifies the way of handling compression (`accept-encoding`) header
    @display {label: "Compression"}
    http:Compression compression = http:COMPRESSION_AUTO;

    # Configurations associated with the behaviour of the Circuit Breaker
    @display {label: "Circuit Breaker Configuration"}
    http:CircuitBreakerConfig circuitBreaker?;

    # Configurations associated with retrying
    @display {label: "Retry Configuration"}
    http:RetryConfig retryConfig?;

    # Configurations associated with inbound response size limits
    @display {label: "Response Limit Configuration"}
    http:ResponseLimitConfigs responseLimits?;

    # SSL/TLS-related options
    @display {label: "Secure Socket Configuration"}
    http:ClientSecureSocket secureSocket?;

    # Proxy server related options
    @display {label: "Proxy Configuration"}
    http:ProxyConfig proxy?;

    # Enables the inbound payload validation functionality which provided by the constraint package. Enabled by default
    @display {label: "Payload Validation"}
    boolean validation = true;
|};

# Models types for Mistral AI
@display {label: "Mistral AI Model Names"}
public enum MISTRAL_AI_MODEL_NAMES {
    MISTRAL_SMALL_LATEST = "mistral-small-latest",
    MISTRAL_MEDIUM_LATEST = "mistral-medium-latest",
    MISTRAL_LARGE_LATEST = "mistral-large-latest",
    DEVSTRAL_SMALL_LATEST = "devstral-small-latest",
    PIXTRAL_LARGE_LATEST = "pixtral-large-latest",
    MINISTRAL_3B_LATEST = "ministral-3b-latest",
    MINISTRAL_8B_LATEST = "ministral-8b-latest",
    MISTRAL_SABA_LATEST = "mistral-saba-latest",
    CODESTRAL_LATEST = "codestral-latest",
    MAGISTRAL_SMALL_LATEST = "magistral-small-latest",
    MISTRAL_SMALL_2402 = "mistral-small-2402",
    MISTRAL_SMALL_2409 = "mistral-small-2409",
    MISTRAL_SMALL_2501 = "mistral-small-2501",
    MISTRAL_SMALL_2503 = "mistral-small-2503",
    MINISTRAL_3B_2410 = "ministral-3b-2410",
    MINISTRAL_8B_2410 = "ministral-8b-2410",
    MISTRAL_MEDIUM_2312 = "mistral-medium-2312",
    MISTRAL_MEDIUM_2505 = "mistral-medium-2505",
    MISTRAL_LARGE_2402 = "mistral-large-2402",
    MISTRAL_LARGE_2407 = "mistral-large-2407",
    MISTRAL_LARGE_2411 = "mistral-large-2411",
    MISTRAL_SABA_2502 = "mistral-saba-2502",
    CODESTRAL_2405 = "codestral-2405",
    CODESTRAL_2501 = "codestral-2501",
    CODESTRAL_MAMBA_2407 = "codestral-mamba-2407",
    DEVSTRAL_SMALL_2505 = "devstral-small-2505",
    OPEN_MISTRAL_7B = "open-mistral-7b",
    OPEN_MISTRAL_NEMO = "open-mistral-nemo",
    OPEN_MIXTRAL_8X7B = "open-mixtral-8x7b",
    OPEN_MIXTRAL_8X22B = "open-mixtral-8x22b",
    PIXTRAL_LARGE_2411 = "pixtral-large-2411",
    PIXTRAL_12B_2409 = "pixtral-12b-2409",
    OPEN_CODESTRAL_MAMBA = "open-codestral-mamba"
}

# Mistral message record.
type MistralMessages mistral:AssistantMessage|mistral:SystemMessage|mistral:UserMessage|mistral:ToolMessage;

// ── Chat Completions streaming types ──────────────────────────────
// Models the `CompletionChunk` carried by the `data` of each Server-Sent Event
// returned by POST /chat/completions when `stream` is true. Field names match the
// raw JSON keys so they bind directly via `fromJsonStringWithType`.
//
// Every record here is open and every field optional or defaulted, and free-form
// values (roles, finish reasons, content-chunk kinds) are typed as `string`/open
// records rather than enums. Binding is all-or-nothing: one unmodelled field or
// one unrecognized enum value fails the whole chunk, and a failed chunk is a
// dropped token. Tolerance at the wire boundary is deliberate - normalization
// and validation happen in the mapping functions below.
// Reference: https://docs.mistral.ai/api/#tag/chat/operation/chat_completion_v1_chat_completions_post

# The `type` of a content fragment carrying the model's chain-of-thought.
const THINKING_CHUNK_TYPE = "thinking";

# The `finish_reason` Mistral sends when generation was aborted by an error.
const FINISH_REASON_ERROR = "error";

# A streamed chunk of a chat completion response (the `data` of one Server-Sent Event).
type CompletionChunk record {
    # Unique identifier for the completion; the same across every chunk
    string id?;
    # Object type, e.g. "chat.completion.chunk"
    string 'object?;
    # Unix timestamp (seconds) of creation; the same across every chunk
    int created?;
    # The model used to generate the completion
    string model?;
    # The list of streamed choices
    CompletionResponseStreamChoice[] choices = [];
    # Token usage statistics; populated on the final chunk
    UsageInfo usage?;
};

# A single choice within a streamed completion chunk.
type CompletionResponseStreamChoice record {
    # Index of the choice in the list of choices
    int index = 0;
    # The incremental message delta for this chunk
    DeltaMessage delta = {};
    # Reason the model stopped generating tokens; `()` until the final chunk.
    # Kept as a `string` rather than an enum: an unrecognized value must degrade
    # to "unknown reason", not fail the chunk. See `mapFinishReason`.
    string? finish_reason = ();
};

# The incremental message content produced in a streamed chunk.
type DeltaMessage record {
    # The message content for this chunk: a plain string or structured content
    # chunks; null or absent for non-content (e.g. tool-call) deltas
    string|DeltaContentChunk[]? content?;
    # Index of the delta; null when not applicable
    int? index?;
    # Arbitrary metadata associated with the delta; null when absent
    map<json>? metadata?;
    # Role of the author of this message; only present on the first delta
    string? role?;
    # Identifier of the tool call this delta belongs to; null for non-tool deltas
    string? tool_call_id?;
    # Incremental tool calls produced by the model
    DeltaToolCall[]? tool_calls?;
};

# A structured content fragment within a streamed delta.
#
# Open by design: the spec's content array also carries `image_url`, `document_url`,
# `reference`, `file` and `audio` chunks, and reasoning models such as
# `magistral-*` stream `thinking` chunks. Only the fields this module projects
# onto the normalized chunk are named; every other kind still binds and is then
# ignored, rather than failing the chunk it arrived in.
type DeltaContentChunk record {
    # The kind of the fragment, e.g. "text" or "thinking"
    string 'type?;
    # The text of a `text` fragment
    string text?;
    # The nested fragments of a `thinking` fragment, themselves usually `text`
    DeltaContentChunk[] thinking?;
};

# An incremental tool call delivered within a streamed delta. With parallel tool
# calling, several tool calls stream concurrently, distinguished by `index`.
type DeltaToolCall record {
    # Index used to correlate fragments of the same tool call across chunks
    int index?;
    # Identifier of the tool call; only present on the first chunk of the call
    string id?;
    # The type of the tool, e.g. "function"; only present on the first chunk
    string 'type?;
    # The function being called
    DeltaFunctionCall 'function?;
};

# The function fragment of a streamed tool call.
type DeltaFunctionCall record {
    # Name of the function to call; only present on the first chunk of the call
    string name?;
    # Incremental fragment of the function arguments, accumulated as a JSON string
    string arguments?;
};

# Token usage statistics for the completion request. Only the three counts the
# normalized `ai:CompletionTokenUsage` can hold are modelled; the rest of the
# spec's fields (cached tokens, audio seconds, prompt breakdowns) land in the
# open rest field, where a shape change cannot break binding.
type UsageInfo record {
    # Number of tokens in the prompt
    int prompt_tokens?;
    # Number of tokens in the generated completion
    int completion_tokens?;
    # Total tokens used (prompt + completion)
    int total_tokens?;
};

// ── Wire → normalized mapping ──────────────────────────────────────────────
// Projects a Mistral `CompletionChunk` (the wire types above) onto the normalized
// `ai:ChatMessageChunk` that `chatAsStream` must return. Only the subset the `ai`
// type can hold is mapped; everything else is ignored. Token usage is not part of
// `ai:ChatMessageChunk` and is reported to the observability span directly from the
// wire chunk instead; see `MistralChunkIterator.recordObservations`.

# Maps a Mistral wire chunk onto the normalized `ai:ChatMessageChunk`.
# Forwards tool calls on every chunk (not just the first), so argument fragments
# stream through correctly.
#
# + wireChunk - The parsed Mistral wire chunk
# + return - The normalized chunk consumed by the `ai` module, or `()` when the
# chunk carries nothing for the caller (no choices, or a delta with no content,
# reasoning, tool calls or finish reason)
isolated function toAiChunk(CompletionChunk wireChunk) returns ai:ChatMessageChunk? {
    CompletionResponseStreamChoice[] choices = wireChunk.choices;
    if choices.length() == 0 {
        return ();
    }
    DeltaMessage wireDelta = choices[0].delta;
    string|DeltaContentChunk[]? wireContent = wireDelta?.content;
    string? content = toContentString(wireContent);
    string? reasoning = toReasoningString(wireContent);

    ai:ToolCallChunk[]? toolCalls = ();
    DeltaToolCall[]? wireToolCalls = wireDelta?.tool_calls;
    if wireToolCalls is DeltaToolCall[] {
        ai:ToolCallChunk[] calls = [];
        // Mistral omits `index` on single tool calls; fall back to the position
        // in the array so fragments of the same call still correlate.
        foreach int i in 0 ..< wireToolCalls.length() {
            DeltaToolCall wireToolCall = wireToolCalls[i];
            ai:ToolCallChunk toolCall = {index: wireToolCall?.index ?: i};
            string? id = wireToolCall?.id;
            if id is string {
                toolCall.id = id;
            }
            DeltaFunctionCall? fn = wireToolCall?.'function;
            if fn is DeltaFunctionCall {
                string? name = fn?.name;
                if name is string {
                    toolCall.name = name;
                }
                string? arguments = fn?.arguments;
                if arguments is string {
                    toolCall.arguments = arguments;
                }
            }
            calls.push(toolCall);
        }
        toolCalls = calls;
    }

    ai:FinishReason? finishReason = mapFinishReason(choices[0].finish_reason);
    if content is () && reasoning is () && toolCalls is () && finishReason is () {
        return ();
    }

    ai:ChatMessageChunk chunk = {role: ai:ASSISTANT, content, reasoning, toolCalls, finishReason};
    string? id = wireChunk?.id;
    if id is string {
        chunk.id = id;
    }
    return chunk;
}

# Flattens a streamed delta's content onto the plain answer text the `ai` chunk
# carries. A delta is usually a bare string; when the model streams structured
# fragments instead, the `text` ones are concatenated and every other kind
# (`thinking`, image/document/reference/file/audio) dropped, since the normalized
# `content` holds answer text only. Reasoning goes to `toReasoningString`.
#
# + content - The `content` of a streamed delta
# + return - The answer text of the delta, or `()` when it carries none
isolated function toContentString(string|DeltaContentChunk[]? content) returns string? {
    if content is string? {
        return content;
    }
    string text = "";
    boolean found = false;
    foreach DeltaContentChunk fragment in content {
        string? fragmentText = fragment?.text;
        // A fragment with no explicit kind but a `text` field is a text fragment;
        // this is how `mistral:TextChunk` arrives on the wire.
        if fragmentText is string && fragment?.'type != THINKING_CHUNK_TYPE {
            text += fragmentText;
            found = true;
        }
    }
    return found ? text : ();
}

# Extracts the reasoning (chain-of-thought) text of a streamed delta.
#
# Reasoning models such as `magistral-*` stream their thinking as `thinking`
# fragments whose own `thinking` field holds nested `text` fragments. The
# normalized `ai:ChatMessageChunk.reasoning` field carries these
# separately from the answer text.
#
# + content - The `content` of a streamed delta
# + return - The reasoning text of the delta, or `()` when it carries none
isolated function toReasoningString(string|DeltaContentChunk[]? content) returns string? {
    if content is string? {
        return ();
    }
    string reasoning = "";
    boolean found = false;
    foreach DeltaContentChunk fragment in content {
        if fragment?.'type != THINKING_CHUNK_TYPE {
            continue;
        }
        DeltaContentChunk[]? nested = fragment?.thinking;
        if nested is () {
            continue;
        }
        foreach DeltaContentChunk thought in nested {
            string? thoughtText = thought?.text;
            if thoughtText is string {
                reasoning += thoughtText;
                found = true;
            }
        }
    }
    return found ? reasoning : ();
}

# Reports whether a wire finish reason means the generation was aborted by the
# model. Mistral's `error` reason has no normalized equivalent - it means the
# response is incomplete, which the caller must not mistake for a clean end of
# stream, so `chatAsStream` fails the stream on it instead of mapping it.
#
# + finishReason - The finish reason from the wire chunk
# + return - Whether the generation was aborted
isolated function isAbortedFinishReason(string? finishReason) returns boolean =>
    finishReason == FINISH_REASON_ERROR;

# Safely maps a Mistral finish reason onto the `ai:FinishReason` enum.
#
# Mistral's documented reasons are `stop`, `length`, `model_length`, `error` and
# `tool_calls`. `model_length` folds into `length` (both mean the token budget
# ran out); `error` is handled by `isAbortedFinishReason` before reaching here.
# Absent and unrecognized reasons map to `()` rather than failing the stream, so
# a reason added to the API later degrades to "no reason given".
#
# + finishReason - The finish reason from the wire chunk
# + return - The mapped `ai:FinishReason`, or `()` when absent/unmappable
isolated function mapFinishReason(string? finishReason) returns ai:FinishReason? {
    match finishReason {
        "stop" => {
            return ai:STOP;
        }
        "length"|"model_length" => {
            return ai:LENGTH;
        }
        "tool_calls" => {
            return ai:TOOL_CALLS;
        }
        "content_filter" => {
            return ai:CONTENT_FILTER;
        }
    }
    return ();
}
