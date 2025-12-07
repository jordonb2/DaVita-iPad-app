import Foundation
import OSLog

/// Centralized structured logging + helpers.
///
/// Use the typed loggers instead of `print`.
enum AppLog {
    static let subsystem: String = {
        Bundle.main.bundleIdentifier ?? "DaVita-iPad-app"
    }()

    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let ui = Logger(subsystem: subsystem, category: "ui")
    static let analytics = Logger(subsystem: subsystem, category: "analytics")

    /// Perf-focused logger + signposter for tracing heavy work.
    static let perf = Logger(subsystem: subsystem, category: "perf")

    @available(iOS 15.0, *)
    static let signposter = OSSignposter(logger: perf)

    enum Redact {
        /// Replace potentially sensitive strings with a token for logging.
        static func pii(_ value: String?) -> String {
            value == nil ? "nil" : "<redacted>"
        }

        /// Public, truncated text to avoid oversized log fields.
        static func `public`(_ value: String?, max: Int = 80) -> String {
            guard var v = value else { return "nil" }
            if v.count > max {
                v = String(v.prefix(max)) + "…"
            }
            return v
        }
    }
}
