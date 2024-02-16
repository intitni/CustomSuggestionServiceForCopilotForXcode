import CopilotForXcodeKit
import Foundation
import SuggestionService

@main
class Extension: CopilotForXcodeExtension {
    var host: HostServer?
    var suggestionService: SuggestionServiceType?
    var chatService: ChatServiceType? { nil }
    var promptToCodeService: PromptToCodeServiceType? { nil }
    var sceneConfiguration = SceneConfiguration()

    required init() {
        let service = SuggestionService()
        suggestionService = service
    }
}

struct SceneConfiguration: CopilotForXcodeExtensionSceneConfiguration {}

