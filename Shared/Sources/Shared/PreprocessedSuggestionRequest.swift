import CopilotForXcodeKit
import Foundation

public protocol PreprocessedSuggestionRequest {
    var systemPrompt: String { get }
    var prefix: [String] { get }
    var suffix: [String] { get }
    var relevantCodeSnippets: [RelevantCodeSnippet] { get }
    
    func createSourcePrompt(truncatedPrefix: [String], truncatedSuffix: [String]) -> String
    func createSnippetsPrompt(includedSnippets: [RelevantCodeSnippet]) -> String
}

public enum Tag {
    public static let openingCode = "<Code3721>"
    public static let closingCode = "</Code3721>"
    public static let openingSnippet = "<Snippet9981>"
    public static let closingSnippet = "</Snippet9981>"
}
