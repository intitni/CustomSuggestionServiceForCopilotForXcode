import CopilotForXcodeKit
import Foundation

public protocol PreprocessedSuggestionRequest {
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
    
    /// Creates a prompt about the source code to be sent to the AI model.
    ///
    /// - Parameters:
    ///  - truncatedPrefix: The truncated source code before the text cursor.
    ///  - truncatedSuffix: The truncated source code after the text cursor.
    ///
    /// - Warning: Please make sure that the prefix and suffix won't cause the whole prompt to
    /// exceed the token limit.
    func createSourcePrompt(truncatedPrefix: [String], truncatedSuffix: [String]) -> String
    /// Creates a prompt about the relevant code snippets to be sent to the AI model.
    ///
    /// - Parameter includedSnippets: The relevant code snippets to be included in the prompt.
    ///   
    /// - Warning: Please make sure that the `includedSnippets` won't cause the whole prompt to
    /// exceed the token limit.
    func createSnippetsPrompt(includedSnippets: [RelevantCodeSnippet]) -> String
}
