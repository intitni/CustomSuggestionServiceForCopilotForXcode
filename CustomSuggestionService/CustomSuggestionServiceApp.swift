import Shared
import SwiftUI

@main
struct CustomSuggestionServiceApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

var isPreview: Bool { ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" }

