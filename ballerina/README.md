## Overview

The `ai.mistral` module provides a Mistral AI-backed `ModelProvider` implementation for the [`ballerina/ai`](https://central.ballerina.io/ballerina/ai/latest) agent framework. Use it to drive Mistral's open-weights chat models from Ballerina AI agents and other `ai`-module abstractions, rather than calling the Mistral REST API directly.

### Key Features

- Seamless integration with high-performance Mistral LLMs
- Support for chat completions and text generation
- Efficient handling of model parameters and prompts
- Simplified access to Mistral AI's API endpoints
- Secure communication with API key authentication
- GraalVM compatible for native image builds

## Prerequisites

Before using this module in your Ballerina application, first you must obtain the nessary configuration to engage the LLM.

- Create a [Mistral account](https://console.mistral.ai/).
- Obtain an API key by following [these instructions](https://docs.mistral.ai/getting-started/quickstart/#account-setup)

## Quickstart

To use the `ai.mistral` module in your Ballerina application, update the `.bal` file as follows:

### Step 1: Import the module

Import the `ai.mistral` module.

```ballerina
import ballerinax/ai.mistral;
```

### Step 2: Intialize the Model Provider

Here's how to initialize the Model Provider:

```ballerina
import ballerina/ai;
import ballerinax/ai.mistral;

final ai:ModelProvider mistralModel = check new mistral:ModelProvider("mistralApiKey", mistral:MINISTRAL_3B_2410);
```

### Step 4: Invoke chat completion

```ballerina
ai:ChatMessage[] chatMessages = [{role: "user", content: "hi"}];
ai:ChatAssistantMessage response = check mistralModel->chat(chatMessages, tools = []);

chatMessages.push(response);
```
