import Foundation

public enum SnapshotDate {
    public static func parse(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
    /// Formats in the app's interface language, not the system region, so an English UI never shows a Korean date.
    public static func display(_ value: String, locale: Locale = .current) -> String? {
        parse(value)?.formatted(.dateTime.year().month(.abbreviated).day().hour().minute().locale(locale))
    }
}
