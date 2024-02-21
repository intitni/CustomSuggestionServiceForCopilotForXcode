import Shared
import SwiftUI

@main
struct CustomSuggestionServiceApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.updateChecker, UpdateChecker(hostBundle: Bundle.main))
        }
        .defaultSize(width: 800, height: 800)
    }
}

var isPreview: Bool { ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" }

struct UpdateCheckerKey: EnvironmentKey {
    static var defaultValue: UpdateChecker = .init(hostBundle: nil)
}

public extension EnvironmentValues {
    var updateChecker: UpdateChecker {
        get { self[UpdateCheckerKey.self] }
        set { self[UpdateCheckerKey.self] = newValue }
    }
}
