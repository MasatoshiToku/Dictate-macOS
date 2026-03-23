import os

public enum AppLogger {
    private static let subsystem = "io.dictate.app"

    /// Create a Logger for the given category
    public static func logger(for category: String) -> Logger {
        return Logger(subsystem: subsystem, category: category)
    }
}
