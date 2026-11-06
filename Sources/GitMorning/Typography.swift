import SwiftUI

enum ReadingSize: String, CaseIterable, Identifiable {
    case standard = "Standard", large = "Large"
    var id: String { rawValue }
    static func fromStored(_ value: String) -> ReadingSize {
        if value == "크게" { return .large }
        return ReadingSize(rawValue: value) ?? .standard
    }
    var scale: CGFloat { self == .large ? 1.125 : 1 }
}

/// macOS caption styles are too small for the app's primary Korean content, so
/// metadata never drops below 13 pt. The scale steps in small increments so a
/// screen reads as one hierarchy instead of competing large sizes.
struct AppTypography {
    var size: ReadingSize = .standard
    private func font(_ points: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: points * size.scale, weight: weight)
    }
    var metadata: Font { font(13) }
    var owner: Font { font(13) }
    var navigation: Font { font(14) }
    var listTitle: Font { font(15, .semibold) }
    var listBody: Font { font(14) }
    var body: Font { font(15) }
    var section: Font { font(15, .semibold) }
    var action: Font { font(13) }
    var brand: Font { font(15, .semibold) }
    var heading: Font { font(19, .semibold) }
    var projectTitle: Font { font(26, .bold) }
    /// Extra leading for Korean text, scaled with the reading size.
    var bodyLeading: CGFloat { 4 * size.scale }
    var listLeading: CGFloat { 2 * size.scale }
}

/// Shared spacing so columns line up.
enum AppSpacing {
    static let column: CGFloat = 16
    static let block: CGFloat = 20
    static let row: CGFloat = 9
}

private struct AppTypographyKey: EnvironmentKey {
    static let defaultValue = AppTypography()
}

extension EnvironmentValues {
    var appTypography: AppTypography {
        get { self[AppTypographyKey.self] }
        set { self[AppTypographyKey.self] = newValue }
    }
}
