import CopilotForXcodeKit
import Foundation
import Shared

/// The default strategy to generate prompts.
///
/// This strategy tries to believe that the model is smart. It will explain carefully what is what
/// and tell the model to complete the code.
struct DefaultRequestStrategy: RequestStrategy {
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
        public static let openingSnippet = "<Snippet9981>"
        public static let closingSnippet = "</Snippet9981>"
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
        Complete code inside \(Tag.openingCode):

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
            return [
                Self.createSnippetsPrompt(includedSnippets: includedSnippets),
                createSourcePrompt(
                    truncatedPrefix: truncatedPrefix,
                    truncatedSuffix: truncatedSuffix
                ),
            ].filter { !$0.isEmpty }
        }

        func createSourcePrompt(truncatedPrefix: [String], truncatedSuffix: [String]) -> String {
            guard let (summary, infillBlock) = Self.createCodeSummary(
                truncatedPrefix: truncatedPrefix,
                truncatedSuffix: truncatedSuffix
            ) else { return "" }

            return """
            Below is the code from file \(filePath) that you are trying to complete.
            Review the code carefully, detect the functionality, formats, style, patterns, \
            and logics in use and use them to predict the completion.
            Make sure your completion has the correct syntax and formatting.
            Enclose the completion the XML tag \(Tag.openingCode).
            Do not duplicate existing implementations.
            Start with a line break if needed.
            Do not put the response in a markdown code block.

            Indentation: \
            \(sourceRequest.indentSize) \(sourceRequest.usesTabsForIndentation ? "tab" : "space")

            Here is the code:
            ```
            \(summary)
            ```

            Complete code inside \(Tag.openingCode):

            \(Tag.openingCode)
            \(infillBlock)
            """
        }

        static func createSnippetsPrompt(includedSnippets: [RelevantCodeSnippet]) -> String {
            guard !includedSnippets.isEmpty else { return "" }
            var content = "References from codebase: \n\n"
            for snippet in includedSnippets {
                content += """
                \(Tag.openingSnippet)
                \(snippet.content)
                \(Tag.closingSnippet)
                """ + "\n\n"
            }
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        static func createCodeSummary(
            truncatedPrefix: [String],
            truncatedSuffix: [String]
        ) -> (summary: String, infillBlock: String)? {
            guard !(truncatedPrefix.isEmpty && truncatedSuffix.isEmpty) else { return nil }
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

            return (
                summary: "\(prefixLines.joined())\(Tag.openingCode)\(Tag.closingCode)\(truncatedSuffix.joined())",
                infillBlock: promptLines.joined()
            )
        }
    }
}
