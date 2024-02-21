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

    let updateChecker =
        UpdateChecker(
            hostBundle: locateHostBundleURL(url: Bundle.main.bundleURL)
                .flatMap(Bundle.init(url:))
        )

    required init() {
        let service = SuggestionService()
        suggestionService = service
    }
}

struct SceneConfiguration: CopilotForXcodeExtensionSceneConfiguration {}

func locateHostBundleURL(url: URL) -> URL? {
    var nextURL = url
    while nextURL.path != "/" {
        nextURL = nextURL.deletingLastPathComponent()
        if nextURL.lastPathComponent.hasSuffix(".app") {
            return nextURL
        }
    }
    let devAppURL = url
        .deletingLastPathComponent()
        .appendingPathComponent("Custom Suggestion Service Dev.app")
    return devAppURL
}
