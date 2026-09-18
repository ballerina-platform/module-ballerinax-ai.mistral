# Ballerina MistralAI Model Provider Library

[![Build](https://github.com/ballerina-platform/module-ballerinax-ai.mistral/workflows/CI/badge.svg)](https://github.com/ballerina-platform/module-ballerinax-ai.mistral/actions?query=workflow%3ACI)
[![GitHub Last Commit](https://img.shields.io/github/last-commit/ballerina-platform/module-ballerinax-ai.mistral.svg)](https://github.com/ballerina-platform/module-ballerinax-ai.mistral/commits/master)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

## Overview

This module provides a generic API for connecting with MistralAI's LLM chat completion models.

### Streaming responses

Alongside `chat` and `generate`, the model provider can stream a response back as it
is produced, so an answer can be rendered while the model is still writing it.

`generateAsStream` streams the answer text of a prompt. Streaming produces text
only - a partial generation is a valid value only for `string`; use `generate`
for structured output.

```ballerina
import ballerina/io;
import ballerinax/ai.mistral;

public function main() returns error? {
    mistral:ModelProvider model = check new (apiKey, mistral:MISTRAL_SMALL_LATEST);

    stream<string, error?> answer = check model->generateAsStream(`Explain streaming in one paragraph.`);
    check from string fragment in answer
        do {
            io:print(fragment);
        };
}
```

`chatAsStream` gives the full chunk stream instead, for callers that need roles, tool
calls, reasoning or finish reasons:

```ballerina
stream<ai:ChatMessageChunk, ai:Error?> chunks = check model->chatAsStream(messages, tools);
check from ai:ChatMessageChunk chunk in chunks
    do {
        io:print(chunk.content ?: "");
    };
```

Reasoning models such as `magistral-small-latest` stream their chain-of-thought in
`reasoning`, separately from the answer text in `content`. `role` is set on every
chunk, and tool-call fragments are correlated by `index`.

The stream releases its connection when it ends. If you stop consuming it early,
close it explicitly with `chunks.close()`.

## Issues and projects

Issues and Projects tabs are disabled for this repository as this is part of the Ballerina Library. To report bugs, request new features, start new discussions, view project boards, etc., go to the [Ballerina Library parent repository](https://github.com/ballerina-platform/ballerina-standard-library).
This repository only contains the source code for the module.

## Build from the source

### Prerequisites

1. Download and install Java SE Development Kit (JDK) version 21 (from one of the following locations).

   - [Oracle](https://www.oracle.com/java/technologies/downloads/)
   - [OpenJDK](https://adoptium.net/)

     > **Note:** Set the JAVA_HOME environment variable to the path name of the directory into which you installed JDK.

2. Generate a GitHub access token with read package permissions, then set the following `env` variables:

   ```shell
   export packageUser=<Your GitHub Username>
   export packagePAT=<GitHub Personal Access Token>
   ```

### Build options

Execute the commands below to build from the source.

1. To build the package:

   ```bash
   ./gradlew clean build
   ```

2. To run the tests:

   ```bash
   ./gradlew clean test
   ```

3. To run a group of tests

   ```bash
   ./gradlew clean test -Pgroups=<test_group_names>
   ```

4. To build the without the tests:

   ```bash
   ./gradlew clean build -x test
   ```

5. To debug the package with a remote debugger:

   ```bash
   ./gradlew clean build -Pdebug=<port>
   ```

6. To debug with Ballerina language:

   ```bash
   ./gradlew clean build -PbalJavaDebug=<port>
   ```

7. Publish the generated artifacts to the local Ballerina central repository:

   ```bash
   ./gradlew clean build -PpublishToLocalCentral=true
   ```

8. Publish the generated artifacts to the Ballerina central repository:

   ```bash
   ./gradlew clean build -PpublishToCentral=true
   ```

## Contribute to Ballerina

As an open-source project, Ballerina welcomes contributions from the community.

For more information, go to the [contribution guidelines](https://github.com/ballerina-platform/ballerina-lang/blob/master/CONTRIBUTING.md).

## Code of conduct

All the contributors are encouraged to read the [Ballerina Code of Conduct](https://ballerina.io/code-of-conduct).
