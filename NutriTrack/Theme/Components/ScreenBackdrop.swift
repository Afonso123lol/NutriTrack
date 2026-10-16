import SwiftUI

struct RidgeLine: Shape {
    let points: [CGPoint]
    let isClosed: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        func place(_ point: CGPoint) -> CGPoint {
            CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height)
        }
        path.move(to: place(first))
        for point in points.dropFirst() { path.addLine(to: place(point)) }
        if isClosed {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}

struct ScreenBackdrop: View {
    @Environment(\.theme) private var theme
    let tone: Color

    static let height: CGFloat = 380

    static func headroom(for style: BackdropStyle) -> CGFloat {
        style == .ridges ? 100 : 12
    }

    private static let farRidge: [CGPoint] = [
        CGPoint(x: 0, y: 0.74), CGPoint(x: 0.109, y: 0.54), CGPoint(x: 0.188, y: 0.65), CGPoint(x: 0.333, y: 0.26),
        CGPoint(x: 0.435, y: 0.51), CGPoint(x: 0.543, y: 0.34), CGPoint(x: 0.674, y: 0.66), CGPoint(x: 0.775, y: 0.46),
        CGPoint(x: 0.891, y: 0.60), CGPoint(x: 1, y: 0.40)
    ]

    private static let nearRidge: [CGPoint] = [
        CGPoint(x: 0, y: 0.86), CGPoint(x: 0.159, y: 0.66), CGPoint(x: 0.275, y: 0.77), CGPoint(x: 0.428, y: 0.55),
        CGPoint(x: 0.580, y: 0.80), CGPoint(x: 0.739, y: 0.63), CGPoint(x: 0.870, y: 0.77), CGPoint(x: 1, y: 0.65)
    ]

    var body: some View {
        Group {
            switch theme.style.backdrop {
            case .ridges:
                ridges
            case .gradient:
                LinearGradient(colors: [theme.colors.accent.opacity(0.16), theme.colors.accent.opacity(0)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea(edges: .top)
            case .glow:
                RadialGradient(colors: [tone.opacity(0.42), tone.opacity(0)],
                               center: UnitPoint(x: 0.3, y: 0.12), startRadius: 0, endRadius: 320)
                    .ignoresSafeArea(edges: .top)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.height, alignment: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var ridges: some View {
        ZStack(alignment: .top) {
            LinearGradient(stops: [.init(color: tone.opacity(0.28), location: 0),
                                   .init(color: tone.opacity(0.11), location: 0.5),
                                   .init(color: tone.opacity(0), location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .top)
            ZStack {
                RidgeLine(points: Self.farRidge, isClosed: true)
                    .fill(theme.colors.textPrimary.opacity(0.035))
                RidgeLine(points: Self.farRidge, isClosed: false)
                    .stroke(theme.colors.textPrimary.opacity(0.16), lineWidth: 1)
                RidgeLine(points: Self.nearRidge, isClosed: true)
                    .fill(theme.colors.background.opacity(0.55))
                RidgeLine(points: Self.nearRidge, isClosed: false)
                    .stroke(theme.colors.textPrimary.opacity(0.10), lineWidth: 1)
            }
            .frame(height: 140)
            .mask(LinearGradient(colors: [theme.colors.background, theme.colors.background,
                                          theme.colors.background.opacity(0)],
                                 startPoint: .top, endPoint: .bottom))
        }
    }
}
