import CopilotForXcodeKit
import Foundation
import Shared

/// This strategy mixed and rearrange everything naively to make the model think it's writing code
/// at the end of a file.
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

    struct Request: PromptStrategy {
        let systemPrompt: String = """
        You are a code completion AI designed to take the surrounding code and \
        references from the codebase into account in order to predict and suggest \
        high-quality code to complete the code enclosed in \(Tag.openingCode) tags.
        You only respond with code that works and fits seamlessly with surrounding code.
        Do not include anything else beyond the code.

        Code completion means to keep writing the code. For example, if I tell you to 
        ###
        Keep writing the following code:
        
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
        var stopWords: [String] { [Tag.closingCode, "\n\n"] }

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
            
            /// Mix and rearrange the file and relevant code snippets.
            let code = {
                var codes = [String]()
                if !includedSnippets.isEmpty {
                    codes.append(includedSnippets.map(\.content).joined(separator: "\n\n"))
                }
                if !truncatedSuffix.isEmpty {
                    codes.append("""
                    // From the end of the file
                    \(truncatedSuffix.joined())
                    // End
                    """)
                }
                codes.append("\(prefixLines.joined())\(promptLines.joined())")
                return codes.joined(separator: "\n\n")
            }()

            return ["""
            File path: \(filePath)
            Indentation: \
            \(sourceRequest.indentSize) \(sourceRequest.usesTabsForIndentation ? "tab" : "space")

            ---
            
            Keep writing the following code:
            
            \(Tag.openingCode)
            \(code)
            """]
        }
    }
}

