import CopilotForXcodeKit
import Foundation
import Parsing
import Shared

/// Prompts may behave differently in different LLMs.
/// This protocol allows for different strategies to be used to generate prompts.
protocol RequestStrategy {
    associatedtype Prompt: PromptStrategy

    init(sourceRequest: SuggestionRequest, prefix: [String], suffix: [String])
    
    /// If the request should be skipped.
    var shouldSkip: Bool { get }

    /// Create a prompt to generate code completion.
    func createPrompt() -> Prompt

    /// The AI model may not return a suggestion in a ideal format. You can use it to reformat the
    /// suggestions.
    ///
    /// By default, it will return the prefix + suggestion.
    func postProcessRawSuggestion(suggestionPrefix: String, suggestion: String) -> String
}

public enum RequestStrategyOption: String, CaseIterable, Codable {
    case `default` = ""
    case naive
    case `continue`
}

extension RequestStrategyOption {
    var strategy: any RequestStrategy.Type {
        switch self {
        case .default:
            return DefaultRequestStrategy.self
        case .naive:
            return NaiveRequestStrategy.self
        case .continue:
            return ContinueRequestStrategy.self
        }
    }
}

// MARK: - Default Implementations

extension RequestStrategy {
    var shouldSkip: Bool { false }
    
    func postProcessRawSuggestion(suggestionPrefix: String, suggestion: String) -> String {
        suggestionPrefix + suggestion
    }
}

// MARK: - Shared Implementations

extension RequestStrategy {
    /// Extract suggestions that is enclosed in tags.
    func extractEnclosingSuggestion(
        from response: String,
        openingTag: String,
        closingTag: String
    ) -> String {
        let case_openingTagAtTheStart_parseEverythingInsideTheTag = Parse(input: Substring.self) {
            openingTag

            OneOf { // parse until tags or the end
                Parse {
                    OneOf {
                        PrefixUpTo(openingTag)
                        PrefixUpTo(closingTag)
                    }
                    Skip {
                        Rest()
                    }
                }

                Rest()
            }
        }

        let case_noTagAtTheStart_parseEverythingBeforeTheTag = Parse(input: Substring.self) {
            OneOf {
                PrefixUpTo(openingTag)
                PrefixUpTo(closingTag)
            }

            Skip {
                Rest()
            }
        }

        let parser = Parse(input: Substring.self) {
            OneOf {
                case_openingTagAtTheStart_parseEverythingInsideTheTag
                case_noTagAtTheStart_parseEverythingBeforeTheTag
                Rest()
            }
        }

        var text = response[...]
        do {
            let suggestion = try parser.parse(&text)
            return String(suggestion)
        } catch {
            return response
        }
    }

    /// If the response starts with markdown code block, we should remove it.
    func removeLeadingAndTrailingMarkdownCodeBlockMark(from response: String) -> String {
        let removePrefixMarkdownCodeBlockMark = Parse(input: Substring.self) {
            Skip {
                "```"
                PrefixThrough("\n")
            }
            OneOf {
                Parse {
                    PrefixUpTo("```")
                    Skip { Rest() }
                }
                Rest()
            }
        }
        
        do {
            var response = response[...]
            let suggestion = try removePrefixMarkdownCodeBlockMark.parse(&response)
            return String(suggestion)
        } catch {
            return response
        }
    }
}

// MARK: - Suggestion Prefix Helpers

extension SuggestionPrefix {
    func curlyBracesLineBreak() -> SuggestionPrefix {
        func mutate(_ string: String) -> String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasSuffix("{") {
                return string + " "
            }
            if trimmed.hasSuffix("}") {
                return string + "\n"
            }
            return string
        }

        let infillValue = mutate(infillValue)
        let prependingValue = mutate(prependingValue)
        return .init(original: original, infillValue: infillValue, prependingValue: prependingValue)
    }
}

