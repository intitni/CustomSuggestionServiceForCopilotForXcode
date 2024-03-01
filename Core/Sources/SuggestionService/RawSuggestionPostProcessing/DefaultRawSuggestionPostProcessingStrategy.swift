import Foundation
import Parsing

protocol RawSuggestionPostProcessingStrategy {
    func postProcessRawSuggestion(suggestionPrefix: String, suggestion: String) -> String
}

struct DefaultRawSuggestionPostProcessingStrategy: RawSuggestionPostProcessingStrategy {
    let openingCodeTag: String
    let closingCodeTag: String

    func postProcessRawSuggestion(suggestionPrefix: String, suggestion: String) -> String {
        let suggestion = extractEnclosingSuggestion(
            from: removeLeadingAndTrailingMarkdownCodeBlockMark(from: suggestion),
            openingTag: openingCodeTag,
            closingTag: closingCodeTag
        )

        if suggestion.hasPrefix(suggestionPrefix) {
            var processed = suggestion
            processed.removeFirst(suggestionPrefix.count)
            return processed
        }

        return suggestionPrefix + suggestion
    }

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

