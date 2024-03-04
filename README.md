# Custom Suggestion Service for Copilot for Xcode

This extension offers a custom suggestion service for [Copilot for Xcode](https://github.com/intitni/CopilotForXcode), allowing you to leverage a chat model to enhance the suggestions provided as you write code.

## Installation

1. Install the application in the Applications folder.
2. Launch the application.
3. Open Copilot for Xcode and navigate to "Extensions".
4. Click "Select Extensions" and enable this extension.
5. You can now set this application as the suggestion provider in the suggestion settings.

## Update

To update the app, you can do so directly within the app itself. Once updated, you should perform one of the following steps to ensure Copilot for Xcode recognizes the new version:

1. Restart the `CopilotForXcodeExtensionService`.
2. Alternatively, terminate the "Custom Suggestion Service (CopilotForXcodeExtensionService)" process, open the extension manager in Copilot for Xcode, and click "Restart Extensions".

We are exploring better methods to tweak the update process.

## Settings

The app supports three types of suggestion services:

- Models with chat completions API
- Models with completions API
- [Tabby](https://tabby.tabbyml.com)

If you are new to running a model locally, you can try [Ollama](https://ollama.com) and [LM Studio](https://lmstudio.ai).

### Recommended Settings

- Use Tabby since they have extensive experience in code completion.
- Use models with completions API with Fill-in-the-Middle support (for example, codellama:7b-code), and use the "Codellama Fill-in-the-Middle" strategy.

### Others

In other situations, it is advisable to use a custom model with the completions API over a chat completions API, and employ the default request strategy.

Ensure that the prompt format remains as simple as the following:

```
{System}
{User}
{Assistant}
```

The template format differs in different tools.

## Strategies

- Default: This strategy meticulously explains the context to the model, prompting it to generate a suggestion.
- Naive: This strategy rearranges the code in a naive way to trick the model into believing it's appending code at the end of a file.
- Continue: This strategy employs the "Please Continue" technique to persuade the model that it has started a suggestion and must continue to complete it. (Only effective with the chat completion API).
- CodeLlama Fill-in-the-Middle: It uses special tokens to guide the models to generate suggestions. The models need to support FIM to use it (codellama:xb-code, startcoder, etc.). This strategy uses the special tokens documented by CodeLlama.
- CodeLlama Fill-in-the-Middle with System Prompt: The previous one doesn't have a system prompt telling it what to do. You can try to use it in models that don't support FIM.

## Contribution

Prompt engineering is a challenging task, and your assistance is invaluable.

The most complex things are located within the `Core` package.

- To add a new service, please refer to the `CodeCompletionService` folder.
- To add new request strategies, check out the `SuggestionService` folder.

