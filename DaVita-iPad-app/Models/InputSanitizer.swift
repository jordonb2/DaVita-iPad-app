import Foundation

/// Shared normalization/sanitization helpers for all user-entered text.
///
/// Goals:
/// - Trim leading/trailing whitespace/newlines
/// - Remove control characters (except newline + tab where appropriate)
/// - Normalize internal whitespace (names/keywords)
/// - Apply consistent max-length caps
enum InputSanitizer {
    enum Guardrails {
        static let maxPersonNameChars: Int = 120
        static let maxGenderChars: Int = 32
        static let maxKeywordChars: Int = 100
    }

    // MARK: - Names

    static func personName(_ raw: String?) -> String? {
        sanitizeSingleLine(raw, max: Guardrails.maxPersonNameChars, collapseWhitespace: true)
    }

    static func gender(_ raw: String?) -> String? {
        sanitizeSingleLine(raw, max: Guardrails.maxGenderChars, collapseWhitespace: true)
    }

    // MARK: - Keywords

    static func searchKeyword(_ raw: String?) -> String? {
        sanitizeSingleLine(raw, max: Guardrails.maxKeywordChars, collapseWhitespace: true)
    }

    // MARK: - Free text / notes

    static func note(_ raw: String?, max: Int) -> String? {
        sanitizeMultiline(raw, max: max)
    }

    // MARK: - Core helpers

    private static func sanitizeSingleLine(_ raw: String?, max: Int, collapseWhitespace: Bool) -> String? {
        guard let raw else { return nil }
        var s = stripControlCharacters(raw, allowNewlines: false)
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if collapseWhitespace {
            s = collapseSpaces(s)
        }
        if s.count > max {
            s = String(s.prefix(max))
        }
        return s.isEmpty ? nil : s
    }

    private static func sanitizeMultiline(_ raw: String?, max: Int) -> String? {
        guard let raw else { return nil }
        var s = stripControlCharacters(raw, allowNewlines: true)
        // Normalize CRLF → LF
        s = s.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if s.count > max {
            s = String(s.prefix(max))
        }
        return s.isEmpty ? nil : s
    }

    private static func collapseSpaces(_ s: String) -> String {
        // Collapse any whitespace run into a single space.
        let parts = s.split(whereSeparator: { $0.isWhitespace })
        return parts.joined(separator: " ")
    }

    private static func stripControlCharacters(_ s: String, allowNewlines: Bool) -> String {
        var scalars: [UnicodeScalar] = []
        scalars.reserveCapacity(s.unicodeScalars.count)

        for u in s.unicodeScalars {
            if allowNewlines {
                // Keep newline + tab to preserve basic formatting for notes.
                if u == "\n" || u == "\t" {
                    scalars.append(u)
                    continue
                }
            }

            if CharacterSet.controlCharacters.contains(u) {
                continue
            }
            scalars.append(u)
        }
        return String(String.UnicodeScalarView(scalars))
    }
}


