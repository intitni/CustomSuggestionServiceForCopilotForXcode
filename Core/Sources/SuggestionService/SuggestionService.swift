import CopilotForXcodeKit
import Foundation
import Fundamental

public class SuggestionService: SuggestionServiceType {
    let service = Service()

    public init() {}

    public var configuration: SuggestionServiceConfiguration {
        .init(acceptsRelevantCodeSnippets: true, mixRelevantCodeSnippetsInSource: false)
    }

    public func notifyAccepted(_ suggestion: CodeSuggestion, workspace: WorkspaceInfo) async {}

    public func notifyRejected(_ suggestions: [CodeSuggestion], workspace: WorkspaceInfo) async {}

    public func cancelRequest(workspace: WorkspaceInfo) async {
        await service.cancelRequest()
    }

    public func getSuggestions(
        _ request: SuggestionRequest,
        workspace: WorkspaceInfo
    ) async throws -> [CodeSuggestion] {
        try await service.getSuggestions(request, workspace: workspace)
    }
}

