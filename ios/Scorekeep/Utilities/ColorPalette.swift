import SwiftUI

enum ColorPalette {
    static let colors: [String] = [
        "#FF4136", // Red
        "#FF851B", // Orange
        "#FFDC00", // Yellow
        "#2ECC40", // Green
        "#01FF70", // Lime
        "#39CCCC", // Cyan
        "#0074D9", // Blue
        "#B10DC9", // Purple
        "#F012BE", // Pink
        "#AAAAAA", // Gray
        "#111111", // Black
        "#FFFFFF", // White
    ]

    static func color(from hex: String) -> Color {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return .gray }
        let r = Double((val >> 16) & 0xFF) / 255
        let g = Double((val >> 8) & 0xFF) / 255
        let b = Double(val & 0xFF) / 255
        return Color(red: r, green: g, blue: b)
    }

    static func textColor(for hex: String) -> Color {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return .white }
        let r = Double((val >> 16) & 0xFF)
        let g = Double((val >> 8) & 0xFF)
        let b = Double(val & 0xFF)
        let luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255
        return luminance > 0.5 ? .black : .white
    }
}
