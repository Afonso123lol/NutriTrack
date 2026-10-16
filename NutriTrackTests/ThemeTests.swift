import XCTest
import SwiftUI
@testable import NutriTrack

final class ThemeTests: XCTestCase {

    func testPresetsHaveDistinctIDsInDisplayOrder() {
        let ids = Theme.all.map(\.id)
        XCTAssertEqual(ids, ["alpine", "instrument", "companion"])
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testPresetLookupReturnsMatchingTheme() {
        for theme in Theme.all {
            XCTAssertEqual(Theme.preset(id: theme.id), theme)
        }
    }

    func testUnknownAndRetiredIDsFallBackToAlpine() {
        XCTAssertEqual(Theme.preset(id: "banana"), .alpine)
        XCTAssertEqual(Theme.preset(id: ""), .alpine)
        XCTAssertEqual(Theme.preset(id: "obsidian"), .alpine)
        XCTAssertEqual(Theme.preset(id: "calm"), .alpine)
    }

    func testThemesDeclareTheirScheme() {
        XCTAssertEqual(Theme.alpine.colorScheme, .dark)
        XCTAssertEqual(Theme.instrument.colorScheme, .dark)
        XCTAssertEqual(Theme.companion.colorScheme, .light)
    }

    func testEachThemeHasItsOwnStyle() {
        XCTAssertEqual(Theme.alpine.style, ThemeStyle(hero: .arc, bar: .hairline, backdrop: .ridges))
        XCTAssertEqual(Theme.instrument.style, ThemeStyle(hero: .numeral, bar: .segmented, backdrop: .gradient))
        XCTAssertEqual(Theme.companion.style, ThemeStyle(hero: .path, bar: .soft, backdrop: .glow))
    }

    func testFontHelpersReadTypographyTokens() {
        let companion = Theme.companion
        XCTAssertEqual(companion.display(20), .system(size: 20, weight: .semibold, design: .rounded))
        XCTAssertEqual(companion.display(.headline), .system(.headline, design: .rounded, weight: .semibold))
        XCTAssertEqual(companion.body(.caption), .system(.caption, design: .rounded))
        XCTAssertEqual(companion.number(20),
                       Font.system(size: 20, weight: .semibold, design: .rounded).width(.standard).monospacedDigit())

        let instrument = Theme.instrument
        XCTAssertEqual(instrument.number(20),
                       Font.system(size: 20, weight: .bold, design: .default).width(.condensed).monospacedDigit())
        XCTAssertEqual(instrument.number(.title3),
                       Font.system(.title3, design: .default, weight: .bold).width(.condensed).monospacedDigit())
        XCTAssertEqual(instrument.hero(60),
                       Font.system(size: 60, weight: .black, design: .default).width(.condensed).monospacedDigit())
        XCTAssertEqual(instrument.meta(.caption), .system(.caption, design: .monospaced))

        XCTAssertEqual(Theme.alpine.display(.headline), .system(.headline, design: .serif, weight: .medium))
        XCTAssertEqual(Theme.alpine.hero(60),
                       Font.system(size: 60, weight: .light, design: .default).width(.standard).monospacedDigit())
    }

    func testHexDecodesChannelsInRGBOrder() {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        UIColor(Color(hex: 0x102030)).getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(Double(r), 16 / 255, accuracy: 1e-6)
        XCTAssertEqual(Double(g), 32 / 255, accuracy: 1e-6)
        XCTAssertEqual(Double(b), 48 / 255, accuracy: 1e-6)
        XCTAssertEqual(Double(a), 1, accuracy: 1e-6)
    }

    func testTextContrastMeetsWCAG() {
        for theme in Theme.all {
            let c = theme.colors
            for (surfaceName, surface) in [("background", c.background), ("surface", c.surface), ("surfaceElevated", c.surfaceElevated)] {
                assertContrast(c.textPrimary, on: surface, atLeast: 4.5, "\(theme.id) textPrimary on \(surfaceName)")
                assertContrast(c.textSecondary, on: surface, atLeast: 4.5, "\(theme.id) textSecondary on \(surfaceName)")
                assertContrast(c.textMuted, on: surface, atLeast: 3.0, "\(theme.id) textMuted on \(surfaceName)")
            }
            assertContrast(c.onAccent, on: c.accent, atLeast: 4.5, "\(theme.id) onAccent on accent")
            assertContrast(c.onAccent, on: c.success, atLeast: 4.5, "\(theme.id) onAccent on success")
            assertContrast(c.onAccent, on: c.coach, atLeast: 4.5, "\(theme.id) onAccent on coach")
            assertContrast(c.coach, on: c.surface, atLeast: 3.0, "\(theme.id) coach on surface")
            let metrics = [("sleep", c.sleep), ("diet", c.diet), ("readiness", c.readiness),
                           ("protein", c.protein), ("carbs", c.carbs), ("fat", c.fat), ("water", c.water)]
            for (metricName, metric) in metrics {
                assertContrast(metric, on: c.surface, atLeast: 3.0, "\(theme.id) \(metricName) on surface")
            }
            assertContrast(c.accent, on: c.surface, atLeast: 3.0, "\(theme.id) accent on surface")
            let states = [("success", c.success), ("warning", c.warning), ("danger", c.danger)]
            for (stateName, state) in states {
                assertContrast(state, on: c.surface, atLeast: 3.0, "\(theme.id) \(stateName) on surface")
            }
            let dayTones = [("dayGo", c.dayGo), ("dayEasy", c.dayEasy), ("dayRest", c.dayRest)]
            for (toneName, tone) in dayTones {
                assertContrast(tone, on: c.background, atLeast: 3.0, "\(theme.id) \(toneName) on background")
                assertContrast(tone, on: c.surface, atLeast: 3.0, "\(theme.id) \(toneName) on surface")
            }
        }
    }

    private func assertContrast(_ foreground: Color, on background: Color, atLeast minimum: Double,
                                _ label: String, file: StaticString = #filePath, line: UInt = #line) {
        let ratio = contrastRatio(foreground, background)
        XCTAssertGreaterThanOrEqual(ratio, minimum,
                                    "\(label): \(String(format: "%.2f", ratio)):1, minimum \(minimum):1",
                                    file: file, line: line)
    }

    private func contrastRatio(_ a: Color, _ b: Color) -> Double {
        let la = relativeLuminance(a)
        let lb = relativeLuminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    private func relativeLuminance(_ color: Color) -> Double {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        func linear(_ channel: CGFloat) -> Double {
            let v = Double(channel)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }
}
