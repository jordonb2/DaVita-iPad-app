import Foundation

/// Shared normalization/sanitization helpers for all user-entered text.
///
/// Goals:
/// - Trim leading/trailing whitespace/newlines
/// - Remove control characters (except newline + tab where appropriate)
/// - Normalize internal whitespace (names/keywords)
/// - Apply consistent max-length caps
enum InputSanitizer {
    // MARK: - Names

    static func personName(_ raw: String?) -> String? {
        sanitizeSingleLine(raw, max: ValidationRules.Person.nameMaxChars, collapseWhitespace: true)
    }

    static func gender(_ raw: String?) -> String? {
        sanitizeSingleLine(raw, max: ValidationRules.Gender.maxChars, collapseWhitespace: true)
    }

    // MARK: - Contact

    static func email(_ raw: String?) -> String? {
        let sanitized = sanitizeSingleLine(raw, max: ValidationRules.Contact.emailMaxChars, collapseWhitespace: true)
        guard let sanitized else { return nil }
        // Very lightweight check: must contain single "@", non-empty local/domain.
        let parts = sanitized.split(separator: "@")
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return nil }
        return sanitized.lowercased()
    }

    static func url(_ raw: String?) -> String? {
        let sanitized = sanitizeSingleLine(raw, max: ValidationRules.Contact.urlMaxChars, collapseWhitespace: false)
        guard let sanitized else { return nil }
        // Basic normalization: prepend https if missing scheme.
        if sanitized.contains("://") {
            return sanitized
        }
        return "https://\(sanitized)"
    }

    static func phone(_ raw: String?) -> String? {
        guard let raw else { return nil }
        // Keep digits and leading plus; strip other characters.
        var filtered = raw.filter { $0.isNumber || $0 == "+" }
        if filtered.hasPrefix("+") {
            // Keep only first plus.
            filtered = "+" + filtered.dropFirst().filter { $0.isNumber }
        }
        if filtered.count > ValidationRules.Contact.phoneMaxChars {
            filtered = String(filtered.prefix(ValidationRules.Contact.phoneMaxChars))
        }
        return filtered.isEmpty ? nil : filtered
    }

    // MARK: - Keywords

    static func searchKeyword(_ raw: String?) -> String? {
        sanitizeSingleLine(raw, max: ValidationRules.Search.keywordMaxChars, collapseWhitespace: true)
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


