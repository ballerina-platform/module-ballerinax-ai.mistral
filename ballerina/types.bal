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

// ── Chat Completions streaming types ───────────────────────────────────────
// Models the `event-stream<CompletionEvent>` returned by POST /chat/completions
// when `stream` is true. Each Server-Sent Event carries one `CompletionEvent`,
// whose `data` field holds a `CompletionChunk`. Field names match the raw JSON
// keys so they bind directly via `fromJsonStringWithType`.
// Structural fields that the spec marks required are kept required; tool-call
// fragment fields are optional because they arrive partially across chunks.
// Reference: https://docs.mistral.ai/api/#tag/chat/operation/chat_completion_v1_chat_completions_post

# A single Server-Sent Event in the chat completion stream.
type CompletionEvent record {
    # The streamed completion chunk carried by this event
    CompletionChunk data;
};

# A streamed chunk of a chat completion response (the `data` of a `CompletionEvent`).
type CompletionChunk record {
    # Unique identifier for the completion; the same across every chunk
    string id;
    # Object type, e.g. "chat.completion.chunk"
    string 'object?;
    # Unix timestamp (seconds) of creation; the same across every chunk
    int created?;
    # The model used to generate the completion
    string model;
    # The list of streamed choices
    CompletionResponseStreamChoice[] choices;
    # Token usage statistics; populated on the final chunk
    UsageInfo usage?;
};

# A single choice within a streamed completion chunk.
type CompletionResponseStreamChoice record {
    # Index of the choice in the list of choices
    int index;
    # The incremental message delta for this chunk
    DeltaMessage delta;
    # Reason the model stopped generating tokens; null until the final chunk.
    # Defaulted rather than required: a chunk that omits the field would otherwise
    # fail to bind and be dropped from the stream.
    FinishReason? finish_reason = ();
};

# The reason the model stopped generating tokens.
# - `stop`: hit a natural stop point or a provided stop sequence
# - `length`: reached the maximum number of tokens specified in the request
# - `model_length`: reached the model's maximum context length
# - `error`: generation stopped due to an error
# - `tool_calls`: the model called a tool
enum FinishReason {
    STOP = "stop",
    LENGTH = "length",
    MODEL_LENGTH = "model_length",
    ERROR = "error",
    TOOL_CALLS = "tool_calls"
}

# The incremental message content produced in a streamed chunk.
type DeltaMessage record {
    # The message content for this chunk: a plain string or structured content
    # chunks; null or absent for non-content (e.g. tool-call) deltas.
    # Note: the spec's content array also includes `FileChunk`/`ThinkChunk`/`AudioChunk`,
    # which `mistral:ContentChunk` (module 1.0.2) does not yet model.
    string|mistral:ContentChunk[]? content?;
    # Index of the delta; null when not applicable
    int? index?;
    # Arbitrary metadata associated with the delta; null when absent
    map<json>? metadata?;
    # Role of the author of this message; only present on the first delta
    string? role?;
    # Identifier of the tool call this delta belongs to; null for non-tool deltas
    string? tool_call_id?;
    # Incremental tool calls produced by the model
    ToolCall[]? tool_calls?;
};

# An incremental tool call delivered within a streamed delta. With parallel tool
# calling, several tool calls stream concurrently, distinguished by `index`.
type ToolCall record {
    # Index used to correlate fragments of the same tool call across chunks
    int index?;
    # Identifier of the tool call; only present on the first chunk of the call
    string id?;
    # The type of the tool, e.g. "function"; only present on the first chunk
    string 'type?;
    # The function being called
    FunctionCall 'function?;
};

# The function fragment of a streamed tool call.
type FunctionCall record {
    # Name of the function to call; only present on the first chunk of the call
    string name?;
    # Incremental fragment of the function arguments, accumulated as a JSON string
    string arguments?;
};

# Token usage statistics for the completion request.
type UsageInfo record {
    # Number of tokens in the generated completion
    int completion_tokens?;
    # Number of prompt tokens served from cache; null when not applicable
    int? num_cached_tokens?;
    # Seconds of prompt audio processed; null when not applicable
    int? prompt_audio_seconds?;
    # Breakdown of the prompt tokens; null when not provided
    PromptTokensDetails? prompt_token_details?;
    # Number of tokens in the prompt
    int prompt_tokens?;
    # Breakdown of the prompt tokens; null when not provided
    PromptTokensDetails? prompt_tokens_details?;
    # Total tokens used (prompt + completion)
    int total_tokens?;
};

# Breakdown of the tokens present in the prompt. The spec leaves the inner shape
# unspecified here, so this is modelled as an open record to accept any fields.
type PromptTokensDetails record {
};

// ── Wire → normalized mapping ──────────────────────────────────────────────
// Projects a Mistral `CompletionChunk` (the wire types above) onto the normalized
// `ai:ChatCompletionChunk` that `chatStream` must return. Only the subset the `ai`
// type can hold is mapped; everything else is ignored.

# Maps a Mistral wire chunk onto the normalized `ai:ChatCompletionChunk`.
# Forwards tool calls on every chunk (not just the first), so argument fragments
# stream through correctly.
#
# + wireChunk - The parsed Mistral wire chunk
# + return - The normalized chunk consumed by the `ai` module
isolated function toAiChunk(CompletionChunk wireChunk) returns ai:ChatCompletionChunk {
    ai:ChatCompletionChunkChoice[] choices = [];
    foreach CompletionResponseStreamChoice choice in wireChunk.choices {
        DeltaMessage wireDelta = choice.delta;
        ai:ChatCompletionChunkDelta delta = {content: toContentString(wireDelta?.content)};
        ai:ROLE? role = mapRole(wireDelta?.role);
        if role is ai:ROLE {
            delta.role = role;
        }
        ToolCall[]? wireToolCalls = wireDelta?.tool_calls;
        if wireToolCalls is ToolCall[] {
            ai:ToolCallChunk[] toolCalls = [];
            // Mistral omits `index` on single tool calls; fall back to the position
            // in the array so fragments of the same call still correlate.
            foreach int i in 0 ..< wireToolCalls.length() {
                ToolCall wireToolCall = wireToolCalls[i];
                ai:ToolCallChunk toolCall = {index: wireToolCall?.index ?: i};
                string? id = wireToolCall?.id;
                if id is string {
                    toolCall.id = id;
                }
                FunctionCall? fn = wireToolCall?.'function;
                if fn is FunctionCall {
                    ai:FunctionCallChunk functionFragment = {};
                    string? name = fn?.name;
                    if name is string {
                        functionFragment.name = name;
                    }
                    string? arguments = fn?.arguments;
                    if arguments is string {
                        functionFragment.arguments = arguments;
                    }
                    toolCall.'function = functionFragment;
                }
                toolCalls.push(toolCall);
            }
            delta.toolCalls = toolCalls;
        }
        choices.push({index: choice.index, delta, finishReason: mapFinishReason(choice.finish_reason)});
    }

    ai:ChatCompletionChunk chunk = {id: wireChunk.id, model: wireChunk.model, choices};
    UsageInfo? usage = wireChunk?.usage;
    if usage is UsageInfo {
        ai:CompletionTokenUsage tokenUsage = {};
        int? promptTokens = usage?.prompt_tokens;
        if promptTokens is int {
            tokenUsage.promptTokens = promptTokens;
        }
        int? completionTokens = usage?.completion_tokens;
        if completionTokens is int {
            tokenUsage.completionTokens = completionTokens;
        }
        int? totalTokens = usage?.total_tokens;
        if totalTokens is int {
            tokenUsage.totalTokens = totalTokens;
        }
        chunk.usage = tokenUsage;
    }
    return chunk;
}

# Flattens a streamed delta's content onto the plain text the `ai` chunk carries.
# A delta is usually a bare string; when the model streams structured content
# chunks instead, the text ones are concatenated and the rest (image/document/
# reference chunks) dropped, since the normalized delta holds text only.
#
# + content - The `content` of a streamed delta
# + return - The text of the delta, or `()` when it carries no text
isolated function toContentString(string|mistral:ContentChunk[]? content) returns string? {
    if content is string? {
        return content;
    }
    string text = "";
    foreach mistral:ContentChunk chunk in content {
        if chunk is mistral:TextChunk {
            text += chunk.text;
        }
    }
    return text == "" ? () : text;
}

# Safely maps a Mistral role string onto the `ai:ROLE` enum; returns `()` for
# absent or unrecognized values rather than panicking on a cast.
#
# + role - The role string from the wire delta
# + return - The mapped `ai:ROLE`, or `()` when absent/unrecognized
isolated function mapRole(string? role) returns ai:ROLE? {
    // Streamed response deltas only carry the "assistant" role; "system"/"user"
    // are handled for completeness. ("function" is request-only and the `ai`
    // enum member is not accessible here, so it is intentionally omitted.)
    match role {
        "system" => {
            return ai:SYSTEM;
        }
        "user" => {
            return ai:USER;
        }
        "assistant" => {
            return ai:ASSISTANT;
        }
    }
    return ();
}

# Safely maps a Mistral finish reason onto the `ai:FinishReason` enum. The `ai`
# enum has no `model_length` or `error` member: `model_length` folds into `length`
# (both mean the token budget ran out), and `error` has no normalized equivalent
# so it maps to `()`. Returns `()` for absent values too.
#
# + finishReason - The finish reason from the wire chunk
# + return - The mapped `ai:FinishReason`, or `()` when absent/unmappable
isolated function mapFinishReason(FinishReason? finishReason) returns ai:FinishReason? {
    match finishReason {
        STOP => {
            return ai:STOP;
        }
        LENGTH|MODEL_LENGTH => {
            return ai:LENGTH;
        }
        TOOL_CALLS => {
            return ai:TOOL_CALLS;
        }
    }
    return ();
}
