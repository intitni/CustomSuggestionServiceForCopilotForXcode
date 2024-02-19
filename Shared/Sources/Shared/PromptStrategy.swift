import CopilotForXcodeKit
import Foundation

public protocol PromptStrategy {
    /// An instruction to the AI model to generate a completion.
    var systemPrompt: String { get }
    /// The source code before the text cursor. Represented as an array of lines.
    var prefix: [String] { get }
    /// The source code after the text cursor. Represented as an array of lines.
    var suffix: [String] { get }
    /// The relevant code snippets that the AI model should consider when generating a completion.
    var relevantCodeSnippets: [RelevantCodeSnippet] { get }
    /// The words at which the AI model should stop generating the completion.
    var stopWords: [String] { get }

    /// Creates a prompt about the source code and relevant code snippets to be sent to the AI
    /// model.
    ///
    /// - Parameters:
    ///  - truncatedPrefix: The truncated source code before the text cursor.
    ///  - truncatedSuffix: The truncated source code after the text cursor.
    ///  - includedSnippets: The relevant code snippets to be included in the prompt.
    ///
    /// - Warning: Please make sure that the prompt won't cause the whole prompt to
    /// exceed the token limit.
    func createPrompt(
        truncatedPrefix: [String],
        truncatedSuffix: [String],
        includedSnippets: [RelevantCodeSnippet]
    ) -> [String]
}

