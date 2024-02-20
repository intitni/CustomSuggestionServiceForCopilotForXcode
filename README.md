#  Custom Suggestion Service for Copilot for Xcode (WIP)

This is an extension that provides a custom suggestion service for Copilot for Xcode. It enables you to use a chat model to provide suggestions for the code you are writing.

## Installation

1. Install the app to the Applications folder.
2. Open the app.
3. Open Copilot for Xcode, and click "Extensions".
4. Click "Select Extensions" and select this app.
5. Then you can change the suggestion provider to this app.

## Settings

It is recommended to use a custom model with completion API, and use the default request strategy.

## Strategies

- Default: This strategy explains everything carefully to the model and ask it to generate a suggestion.
- Naive: This strategy remixes the code and snippets into the prompt to fool the model that it's writing code at the end of a file.
- Continue: This strategy use the "Please Continue" technique to fool the model that it has generated a part of the suggestion, but needs to continue to generate the rest. (Only work with the chat completion API).

## Contribution

Prompt engineering is really hard and we really need your help. 

Most hard things are in the `Shared` package. If you want to add a new model service, please check the file `CodeCompletionService.swift`. If you want to add new request strategies, please check the file `RequestStrategy.swift`.
