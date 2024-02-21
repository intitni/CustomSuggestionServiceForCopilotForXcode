import Sparkle

public final class UpdateChecker {
    let updater: SPUUpdater
    let hostBundleFound: Bool
    let delegate = UpdaterDelegate()

    public init(hostBundle: Bundle?) {
        if hostBundle == nil {
            hostBundleFound = false
            print("Host bundle not found")
        } else {
            hostBundleFound = true
        }
        updater = SPUUpdater(
            hostBundle: hostBundle ?? Bundle.main,
            applicationBundle: Bundle.main,
            userDriver: SPUStandardUserDriver(hostBundle: hostBundle ?? Bundle.main, delegate: nil),
            delegate: delegate
        )
        do {
            try updater.start()
        } catch {
            print(error.localizedDescription)
        }
    }

    public func checkForUpdates() {
        updater.checkForUpdates()
    }

    public var automaticallyChecksForUpdates: Bool {
        get { updater.automaticallyChecksForUpdates }
        set { updater.automaticallyChecksForUpdates = newValue }
    }
}

class UpdaterDelegate: NSObject, SPUUpdaterDelegate {
    func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        if UserDefaults.shared.value(for: \.installBetaBuild) {
            Set(["beta"])
        } else {
            []
        }
    }
}

