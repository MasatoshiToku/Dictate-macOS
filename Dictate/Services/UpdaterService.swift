import Foundation
import Sparkle
import os

final class UpdaterService {
    private let updaterController: SPUStandardUpdaterController
    private let logger = Logger(subsystem: "io.dictate.app", category: "updater")

    init() {
        // Initialize Sparkle updater
        // The SPUStandardUpdaterController reads SUFeedURL and SUPublicEDKey from Info.plist
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        logger.info("Sparkle updater initialized")
    }

    var updater: SPUUpdater {
        updaterController.updater
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    var canCheckForUpdates: Bool {
        updaterController.updater.canCheckForUpdates
    }

    var automaticallyChecksForUpdates: Bool {
        get { updaterController.updater.automaticallyChecksForUpdates }
        set { updaterController.updater.automaticallyChecksForUpdates = newValue }
    }
}
