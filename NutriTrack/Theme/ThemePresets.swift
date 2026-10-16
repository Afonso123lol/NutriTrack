import SwiftUI

nonisolated extension Theme {
    static let alpine = Theme(
        id: "alpine",
        name: "Alpine",
        tagline: "Dark, calm, the mountain ahead.",
        colorScheme: .dark,
        colors: ThemeColors(
            background: Color(hex: 0x0B0C0F),
            surface: Color(hex: 0x14161B),
            surfaceElevated: Color(hex: 0x1C1F26),
            border: Color(hex: 0x2A2D35),
            textPrimary: Color(hex: 0xF1EEE6),
            textSecondary: Color(hex: 0xB4B7BE),
            textMuted: Color(hex: 0x8E9199),
            accent: Color(hex: 0x8ADDB0),
            onAccent: Color(hex: 0x0C2A1C),
            sleep: Color(hex: 0x8FB4E8),
            diet: Color(hex: 0xE0A56B),
            readiness: Color(hex: 0x8ADDB0),
            protein: Color(hex: 0xF09A86),
            carbs: Color(hex: 0xE9C46A),
            fat: Color(hex: 0x9DB7FF),
            water: Color(hex: 0x7FD3E6),
            success: Color(hex: 0x8ADDB0),
            warning: Color(hex: 0xE9C46A),
            danger: Color(hex: 0xF0655A),
            coach: Color(hex: 0xC3B1F2),
            dayGo: Color(hex: 0x8ADDB0),
            dayEasy: Color(hex: 0xE9C46A),
            dayRest: Color(hex: 0xD98B6B)
        ),
        typography: ThemeTypography(
            displayDesign: .serif,
            displayWeight: .medium,
            numberDesign: .default,
            numberWeight: .medium,
            numberWidth: .standard,
            heroWeight: .light,
            bodyDesign: .default,
            metaDesign: .default,
            isEyebrowUppercase: true,
            eyebrowTracking: 2,
            titleTracking: 0
        ),
        shape: ThemeShape(cardRadius: 20, controlRadius: 18, cardStyle: .lit, ringWidth: 4, ringCap: .round),
        style: ThemeStyle(hero: .arc, bar: .hairline, backdrop: .ridges)
    )

    static let instrument = Theme(
        id: "instrument",
        name: "Instrument",
        tagline: "Dense, precise, a cockpit.",
        colorScheme: .dark,
        colors: ThemeColors(
            background: Color(hex: 0x090B0F),
            surface: Color(hex: 0x121820),
            surfaceElevated: Color(hex: 0x1A222C),
            border: Color(hex: 0x26313B),
            textPrimary: Color(hex: 0xEAF2F6),
            textSecondary: Color(hex: 0xB5C4CC),
            textMuted: Color(hex: 0x8195A0),
            accent: Color(hex: 0x8FE9FF),
            onAccent: Color(hex: 0x06222B),
            sleep: Color(hex: 0xA9B8FF),
            diet: Color(hex: 0xFFB37A),
            readiness: Color(hex: 0x8FE9FF),
            protein: Color(hex: 0xFF9C8A),
            carbs: Color(hex: 0xF2D27A),
            fat: Color(hex: 0x7FB0F5),
            water: Color(hex: 0x8FE9FF),
            success: Color(hex: 0xB8F2A0),
            warning: Color(hex: 0xF2D27A),
            danger: Color(hex: 0xFF6B5E),
            coach: Color(hex: 0xC9B8FF),
            dayGo: Color(hex: 0xB8F2A0),
            dayEasy: Color(hex: 0xF2D27A),
            dayRest: Color(hex: 0xE39A7A)
        ),
        typography: ThemeTypography(
            displayDesign: .default,
            displayWeight: .heavy,
            numberDesign: .default,
            numberWeight: .bold,
            numberWidth: .condensed,
            heroWeight: .black,
            bodyDesign: .default,
            metaDesign: .monospaced,
            isEyebrowUppercase: true,
            eyebrowTracking: 1.6,
            titleTracking: -0.3
        ),
        shape: ThemeShape(cardRadius: 10, controlRadius: 6, cardStyle: .outlined, ringWidth: 5, ringCap: .butt),
        style: ThemeStyle(hero: .numeral, bar: .segmented, backdrop: .gradient)
    )

    static let companion = Theme(
        id: "companion",
        name: "Companion",
        tagline: "Light, soft, on your side.",
        colorScheme: .light,
        colors: ThemeColors(
            background: Color(hex: 0xF4F1EA),
            surface: Color(hex: 0xFFFFFF),
            surfaceElevated: Color(hex: 0xFBF9F5),
            border: Color(hex: 0xE6E1D8),
            textPrimary: Color(hex: 0x2A2926),
            textSecondary: Color(hex: 0x6F6B64),
            textMuted: Color(hex: 0x857F76),
            accent: Color(hex: 0x3F7A5E),
            onAccent: Color(hex: 0xFFFFFF),
            sleep: Color(hex: 0x7C6FC9),
            diet: Color(hex: 0xC5773F),
            readiness: Color(hex: 0x3F7A5E),
            protein: Color(hex: 0xD0705C),
            carbs: Color(hex: 0xB08A2E),
            fat: Color(hex: 0x5F8FC2),
            water: Color(hex: 0x4F97AD),
            success: Color(hex: 0x3F7A5E),
            warning: Color(hex: 0xB08A2E),
            danger: Color(hex: 0xD2493F),
            coach: Color(hex: 0x6F5BC4),
            dayGo: Color(hex: 0x3F7A5E),
            dayEasy: Color(hex: 0x9A7620),
            dayRest: Color(hex: 0xB8623A)
        ),
        typography: ThemeTypography(
            displayDesign: .rounded,
            displayWeight: .semibold,
            numberDesign: .rounded,
            numberWeight: .semibold,
            numberWidth: .standard,
            heroWeight: .semibold,
            bodyDesign: .rounded,
            metaDesign: .rounded,
            isEyebrowUppercase: false,
            eyebrowTracking: 0,
            titleTracking: 0
        ),
        shape: ThemeShape(cardRadius: 26, controlRadius: 18, cardStyle: .filled, ringWidth: 8, ringCap: .round),
        style: ThemeStyle(hero: .path, bar: .soft, backdrop: .glow)
    )

    static let all: [Theme] = [.alpine, .instrument, .companion]

    static func preset(id: String) -> Theme {
        all.first { $0.id == id } ?? .alpine
    }
}
