import CopilotForXcodeKit
import Foundation
import Shared

struct NaiveRequestStrategy: RequestStrategy {
    var sourceRequest: SuggestionRequest
    var prefix: [String]
    var suffix: [String]

    func createRequest() -> Request {
        Request(
            sourceRequest: sourceRequest,
            prefix: prefix,
            suffix: suffix
        )
    }

    enum Tag {
        public static let openingCode = "<Code3721>"
        public static let closingCode = "</Code3721>"
    }

    struct Request: PreprocessedSuggestionRequest {
        let systemPrompt: String = """
        You are a code completion AI designed to take the surrounding code and \
        references from the codebase into account in order to predict and suggest \
        high-quality code to complete the code enclosed in \(Tag.openingCode) tags.
        You only respond with code that works and fits seamlessly with surrounding code.
        Do not include anything else beyond the code.

        Code completion means to keep writing the code. For example, if I tell you to 
        ###
        complete the code inside \(Tag.openingCode):

        \(Tag.openingCode)
        print("Hello
        ###

        You should respond with:
        ###
         World")\(Tag.closingCode)
        ###
        """
        var sourceRequest: SuggestionRequest
        var prefix: [String]
        var suffix: [String]
        var filePath: String { sourceRequest.fileURL.path }
        var relevantCodeSnippets: [RelevantCodeSnippet] { sourceRequest.relevantCodeSnippets }
        var stopWords: [String] { [Tag.closingCode] }

        func createPrompt(
            truncatedPrefix: [String],
            truncatedSuffix: [String],
            includedSnippets: [RelevantCodeSnippet]
        ) -> [String] {
            let promptLinesCount = min(10, max(truncatedPrefix.count, 2))
            let prefixLines = truncatedPrefix.prefix(truncatedPrefix.count - promptLinesCount)
            let promptLines: [String] = {
                let proposed = truncatedPrefix.suffix(promptLinesCount)
                if let last = proposed.last,
                   last.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                {
                    return Array(proposed) + [
                        """
                        // write some code
                        \(last)
                        """,
                    ]
                }
                return Array(proposed)
            }()

            return ["""
            // File path: \(filePath)
            // Indentation: \
            \(sourceRequest.indentSize) \(sourceRequest.usesTabsForIndentation ? "tab" : "space")

            Keep writing the following code:

            \(Tag.openingCode)
            \(includedSnippets.map(\.content).joined(separator: "\n\n"))

            \(prefixLines.joined())\(promptLines.joined())
            """]
        }
    }
}

