import SwiftUI

struct TargetBar: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let geometry: TargetBarGeometry
    let color: Color
    var isProminent = false
    var zoneColor: Color? = nil

    @State private var progress = 0.0

    private static let segmentCount = 20

    private var height: CGFloat {
        switch theme.style.bar {
        case .hairline: return isProminent ? 6 : 4
        case .segmented: return isProminent ? 9 : 3
        case .soft: return isProminent ? 12 : 8
        }
    }

    private var fillColor: Color { geometry.isOver ? theme.colors.danger : color }

    var body: some View {
        Group {
            if theme.style.bar == .segmented && isProminent {
                segments
            } else {
                track
            }
        }
        .frame(height: height + 6)
        .onAppear {
            if reduceMotion {
                progress = 1
            } else {
                withAnimation(.easeOut(duration: 0.7)) { progress = 1 }
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.4), value: geometry)
        .accessibilityHidden(true)
    }

    private var track: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let radius = theme.style.bar == .segmented ? 1.5 : height / 2
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: radius)
                    .fill(theme.colors.border)
                    .frame(height: height)
                if let zone = geometry.zone {
                    RoundedRectangle(cornerRadius: radius)
                        .fill((zoneColor ?? color).opacity(0.28))
                        .frame(width: max(0, width * (zone.upperBound - zone.lowerBound)), height: height)
                        .offset(x: width * zone.lowerBound)
                }
                RoundedRectangle(cornerRadius: radius)
                    .fill(fillColor)
                    .frame(width: max(0, width * geometry.fill * progress), height: height)
                if let tick = geometry.tick {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(theme.colors.textPrimary)
                        .frame(width: 2, height: height + 6)
                        .offset(x: min(width - 2, max(0, width * tick - 1)))
                }
            }
            .frame(height: height + 6)
        }
    }

    private var segments: some View {
        let filled = geometry.filledSegments(of: Self.segmentCount)
        return HStack(spacing: 2.5) {
            ForEach(0..<Self.segmentCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(index < filled ? fillColor : theme.colors.border)
                    .frame(height: height)
            }
        }
    }
}
