import SwiftUI

extension Color {
    static let fin1ScreenBackground = Color("ScreenBackground")
    static let fin1SectionBackground = Color("SectionBackground")
    static let fin1SectionBackgroundAlt1 = Color(hex: "#213F81")
    static let fin1SectionBackgroundAlt2 = Color(hex: "#152852")
    static let fin1ScrollSectionBackground = Color("ScrollSectionBackground")
    static let fin1AccentLightBlue = Color("AccentLightBlue")
    static let fin1AccentGreen = Color("AccentGreen")
    static let fin1AccentRed = Color("AccentRed")
    static let fin1AccentOrange = Color("AccentOrange")
    static let fin1InputFieldBackground = Color("InputFieldBackground")
    static let fin1InputFieldPlaceholder = Color("InputFieldPlaceholder")
    static let fin1InputText = Color("InputText")
    static let fin1FontColor = Color("FontColor")
}

// MARK: - Color Extension for Hex Support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let alpha, red, green, blue: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (alpha, red, green, blue) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (alpha, red, green, blue) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (alpha, red, green, blue) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (alpha, red, green, blue) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: Double(alpha) / 255
        )
    }
}
