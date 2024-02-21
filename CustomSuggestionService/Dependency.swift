import CopilotForXcodeKit
import Dependencies
import SuggestionService

// MARK: - SuggestionService

struct SuggestionServiceDependencyKey: DependencyKey {
    static var liveValue: SuggestionServiceType = SuggestionService()
    static var previewValue: SuggestionServiceType = MockSuggestionService()
}

struct MockSuggestionService: SuggestionServiceType {
    var configuration: SuggestionServiceConfiguration {
        .init(acceptsRelevantCodeSnippets: true, mixRelevantCodeSnippetsInSource: false)
    }

    func getSuggestions(
        _: SuggestionRequest,
        workspace: WorkspaceInfo
    ) async throws -> [CodeSuggestion] {
        [.init(id: "id", text: "Hello World", position: .zero, range: .zero)]
    }

    func notifyAccepted(_: CodeSuggestion, workspace: WorkspaceInfo) async {
        print("Accepted")
    }

    func notifyRejected(_: [CodeSuggestion], workspace: WorkspaceInfo) async {
        print("Rejected")
    }

    func cancelRequest(workspace: WorkspaceInfo) async {
        print("Cancelled")
    }
}

extension DependencyValues {
    var suggestionService: SuggestionServiceType {
        get { self[SuggestionServiceDependencyKey.self] }
        set { self[SuggestionServiceDependencyKey.self] = newValue }
    }
}

