import SwiftUI

nonisolated enum CardStyle: Sendable {
    case filled
    case outlined
    case lit
}

nonisolated enum HeroStyle: Sendable {
    case arc
    case numeral
    case path
}

nonisolated enum BarStyle: Sendable {
    case hairline
    case segmented
    case soft
}

nonisolated enum BackdropStyle: Sendable {
    case ridges
    case gradient
    case glow
}

nonisolated struct ThemeStyle: Equatable, Sendable {
    let hero: HeroStyle
    let bar: BarStyle
    let backdrop: BackdropStyle
}

nonisolated struct ThemeColors: Equatable, Sendable {
    let background: Color
    let surface: Color
    let surfaceElevated: Color
    let border: Color
    let textPrimary: Color
    let textSecondary: Color
    let textMuted: Color
    let accent: Color
    let onAccent: Color
    let sleep: Color
    let diet: Color
    let readiness: Color
    let protein: Color
    let carbs: Color
    let fat: Color
    let water: Color
    let success: Color
    let warning: Color
    let danger: Color
    let coach: Color
    let dayGo: Color
    let dayEasy: Color
    let dayRest: Color
}

nonisolated struct ThemeTypography: Equatable, Sendable {
    let displayDesign: Font.Design
    let displayWeight: Font.Weight
    let numberDesign: Font.Design
    let numberWeight: Font.Weight
    let numberWidth: Font.Width
    let heroWeight: Font.Weight
    let bodyDesign: Font.Design
    let metaDesign: Font.Design
    let isEyebrowUppercase: Bool
    let eyebrowTracking: CGFloat
    let titleTracking: CGFloat
}

nonisolated struct ThemeShape: Equatable, Sendable {
    let cardRadius: CGFloat
    let controlRadius: CGFloat
    let cardStyle: CardStyle
    let ringWidth: CGFloat
    let ringCap: CGLineCap
}

nonisolated struct Theme: Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let tagline: String
    let colorScheme: ColorScheme
    let colors: ThemeColors
    let typography: ThemeTypography
    let shape: ThemeShape
    let style: ThemeStyle

    func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: typography.displayWeight, design: typography.displayDesign)
    }

    func number(_ size: CGFloat) -> Font {
        Font.system(size: size, weight: typography.numberWeight, design: typography.numberDesign)
            .width(typography.numberWidth).monospacedDigit()
    }

    func hero(_ size: CGFloat) -> Font {
        Font.system(size: size, weight: typography.heroWeight, design: typography.numberDesign)
            .width(typography.numberWidth).monospacedDigit()
    }

    func body(_ style: Font.TextStyle) -> Font {
        .system(style, design: typography.bodyDesign)
    }

    func display(_ style: Font.TextStyle) -> Font {
        .system(style, design: typography.displayDesign, weight: typography.displayWeight)
    }

    func number(_ style: Font.TextStyle) -> Font {
        Font.system(style, design: typography.numberDesign, weight: typography.numberWeight)
            .width(typography.numberWidth).monospacedDigit()
    }

    func meta(_ style: Font.TextStyle) -> Font {
        .system(style, design: typography.metaDesign)
    }
}

extension Color {
    nonisolated init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
