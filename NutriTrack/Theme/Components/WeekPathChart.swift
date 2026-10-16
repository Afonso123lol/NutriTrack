import SwiftUI

struct WeekPathChart: View {
    @Environment(\.theme) private var theme
    let path: WeekPath
    let color: Color
    var height: CGFloat = 110

    private var top: Double {
        max(path.upper(at: 6), path.doneSoFar, 1) * 1.15
    }

    private var margin: Double { top * 0.045 }

    private func point(slot: Int, _ value: Double, in size: CGSize) -> CGPoint {
        let inset: CGFloat = 12
        let x = inset + CGFloat(slot) * (size.width - 2 * inset) / 7
        let y = size.height - 12 - CGFloat(max(value, 0) / top) * (size.height - 26)
        return CGPoint(x: x, y: y)
    }

    private func planned(atSlot slot: Int) -> Double {
        slot == 0 ? 0 : path.days[slot - 1].planned
    }

    private func band(lowerShare: Double, upperShare: Double, margin: Double, in size: CGSize) -> Path {
        var shape = Path()
        shape.move(to: point(slot: 0, planned(atSlot: 0) * upperShare + margin, in: size))
        for slot in 1...7 { shape.addLine(to: point(slot: slot, planned(atSlot: slot) * upperShare + margin, in: size)) }
        for slot in (0...7).reversed() {
            shape.addLine(to: point(slot: slot, planned(atSlot: slot) * lowerShare - margin, in: size))
        }
        shape.closeSubpath()
        return shape
    }

    private func didTrain(_ index: Int) -> Bool {
        path.days[index].done > (index > 0 ? path.days[index - 1].done : 0)
    }

    private var marks: [(slot: Int, value: Double, isFilled: Bool, isToday: Bool)] {
        var result: [(slot: Int, value: Double, isFilled: Bool, isToday: Bool)] = []
        for index in 0..<path.todayIndex {
            result.append((index + 1, path.days[index].done, didTrain(index), false))
        }
        let today = path.todayIndex
        result.append((didTrain(today) ? today + 1 : today, path.days[today].done, didTrain(today), true))
        return result
    }

    private func line(in size: CGSize) -> Path {
        var shape = Path()
        shape.move(to: point(slot: 0, 0, in: size))
        for mark in marks { shape.addLine(to: point(slot: mark.slot, mark.value, in: size)) }
        return shape
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                band(lowerShare: WeekPath.lowerShare, upperShare: WeekPath.upperShare, margin: margin, in: size)
                    .fill(color.opacity(0.16))
                band(lowerShare: 0.95, upperShare: 1.03, margin: margin * 0.4, in: size)
                    .fill(color.opacity(0.22))
                line(in: size)
                    .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [2, 5]))
                ForEach(marks, id: \.slot) { mark in
                    let diameter: CGFloat = mark.isToday ? 14 : (mark.isFilled ? 10 : 7)
                    Circle()
                        .fill(mark.isFilled ? color : theme.colors.surface)
                        .overlay(Circle().strokeBorder(color, lineWidth: mark.isToday ? 2.5 : 1.5))
                        .frame(width: diameter, height: diameter)
                        .position(point(slot: mark.slot, mark.value, in: size))
                }
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("This week")
        .accessibilityValue("\(Int(path.doneSoFar)) of \(Int(path.totalPlanned)) minutes. \(path.status.label)")
    }
}
