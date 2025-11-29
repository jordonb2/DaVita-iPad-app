import Foundation
import OSLog

/// Centralized structured logging.
///
/// Use `AppLog.persistence`, `AppLog.ui`, `AppLog.analytics` instead of `print`.
enum AppLog {
    static let subsystem: String = {
        Bundle.main.bundleIdentifier ?? "DaVita-iPad-app"
    }()

    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let ui = Logger(subsystem: subsystem, category: "ui")
    static let analytics = Logger(subsystem: subsystem, category: "analytics")
}
