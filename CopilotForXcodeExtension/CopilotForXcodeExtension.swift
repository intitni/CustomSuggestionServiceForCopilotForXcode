import CopilotForXcodeKit
import Foundation
import SuggestionService

@main
class Extension: CopilotForXcodeExtension {
    let suggestionService = SuggestionService()
    var sceneConfiguration = SceneConfiguration()

    let updateChecker =
        UpdateChecker(
            hostBundle: locateHostBundleURL(url: Bundle.main.bundleURL)
                .flatMap(Bundle.init(url:))
        )
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
