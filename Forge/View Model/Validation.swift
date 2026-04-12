import Foundation

enum Validation {
    static let maxNameLength = 50

    /// Trims whitespace and returns the cleaned string, or nil if empty.
    /// Truncates to `maxNameLength` characters.
    static func trimmedName(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.count > maxNameLength ? String(trimmed.prefix(maxNameLength)) : trimmed
    }
}
