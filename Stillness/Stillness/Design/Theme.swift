import SwiftUI

/// Design tokens. Placeholder palette: `/replica-design` and `/replica-brand` replace these values, not the names.
enum Theme {
    static let background = Color(hex: 0x17121F)
    static let surface = Color(hex: 0x241C30)
    static let surfaceRaised = Color(hex: 0x30263F)
    static let border = Color.white.opacity(0.12)
    static let text = Color(hex: 0xF5F0FA)
    static let textMuted = Color(hex: 0xB9AFC8)
    static let accent = Color(hex: 0xF2B880)
    static let onAccent = Color(hex: 0x2A1A0E)
    static let danger = Color(hex: 0xFF7A7A)
    static let success = Color(hex: 0x8FD6A8)

    enum Radius {
        static let small: CGFloat = 10
        static let medium: CGFloat = 14
        static let large: CGFloat = 22
    }

    static func gradient(_ hexes: [String]) -> LinearGradient {
        let colors = hexes.compactMap { Color(hexString: $0) }
        return LinearGradient(
            colors: colors.isEmpty ? [surface, surfaceRaised] : colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    init?(hexString: String) {
        var string = hexString.trimmingCharacters(in: .whitespaces)
        if string.hasPrefix("#") { string.removeFirst() }
        guard string.count == 6, let value = UInt32(string, radix: 16) else { return nil }
        self.init(hex: value)
    }
}
