import SwiftUI
import CoreData

struct CalibrationView: View {
    @Environment(\.theme) private var theme
    @Environment(\.managedObjectContext) private var ctx
    @ObservedObject var profile: UserProfile

    private var report: CalibrationReport {
        CalibrationReport.make(TrainingService.calibrationDays(since: profile.calibrationStartedAt, in: ctx))
    }

    private var isRunning: Bool {
        Calibration.isRunning(startedAt: profile.calibrationStartedAt, now: Date(),
                              yellowDaysWithSession: TrainingService.yellowDaysWithSession(
                                since: profile.calibrationStartedAt ?? Date(), in: ctx))
    }

    private var statusText: String {
        guard profile.calibrationStartedAt != nil else {
            return "Calibration starts with your next check-in. For a few weeks, yellow days only suggest."
        }
        guard isRunning else { return "Here is what your yellow days looked like." }
        let week = Calibration.weeksDone(startedAt: profile.calibrationStartedAt, now: Date()) + 1
        return "Week \(week) of up to \(Int(Calibration.maximumWeeks)). Yellow days only suggest for now."
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                let report = report
                VStack(alignment: .leading, spacing: 8) {
                    EyebrowText(isRunning ? "Still learning" : "Calibration")
                    Text(statusText)
                        .font(theme.body(.subheadline))
                        .foregroundStyle(theme.colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .themedCard()

                comparison(report)

                Group {
                    if let verdict = report.verdict {
                        Text(verdict)
                            .font(theme.body(.subheadline))
                            .foregroundStyle(theme.colors.textPrimary)
                    } else {
                        Text("\(report.yellowSide.days) informative yellow \(report.yellowSide.days == 1 ? "day" : "days") so far. No conclusion under \(CalibrationReport.minimumDays).")
                            .font(theme.body(.caption))
                            .foregroundStyle(theme.colors.textSecondary)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .themedCard()

                modePicker
            }
            .padding(16)
        }
        .background(theme.colors.background.ignoresSafeArea())
        .navigationTitle("Yellow days")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func comparison(_ report: CalibrationReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowText("Yellow days, plan kept")
            sideRows(report.yellowSide)
            Divider()
            EyebrowText("Green days")
            sideRows(report.greenSide)
            if report.acceptedSide.days > 0 {
                Divider()
                Text(report.acceptedSide.days == 1
                     ? "1 yellow day where you took the lighter session is left out: you trained less, so it cannot tell whether the rule is right."
                     : "\(report.acceptedSide.days) yellow days where you took the lighter session are left out: you trained less, so they cannot tell whether the rule is right.")
                    .font(theme.body(.caption))
                    .foregroundStyle(theme.colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    @ViewBuilder
    private func sideRows(_ side: CalibrationReport.Side) -> some View {
        row("Days", "\(side.days)")
        row("Sessions", "\(side.sessions)")
        row("Median effort", side.medianRPE.map { String(format: "%.1f of 10", $0) } ?? "—")
        row("Minutes done", side.medianDoneShare.map { "\(Int(($0 * 100).rounded()))% of plan" } ?? "—")
        row("Day energy", side.medianDayEnergy.map { String(format: "%.1f of 5", $0) } ?? "—")
    }

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            EyebrowText("What a yellow day does")
            ForEach(YellowMode.allCases, id: \.self) { mode in
                Button {
                    profile.yellowMode = mode.rawValue
                    try? ctx.save()
                } label: {
                    HStack {
                        Text(mode.label)
                            .font(theme.body(.subheadline))
                            .foregroundStyle(theme.colors.textPrimary)
                        Spacer()
                        if profile.yellowModeValue == mode {
                            Image(systemName: "checkmark")
                                .foregroundStyle(theme.colors.accent)
                                .accessibilityHidden(true)
                        }
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isRunning || profile.calibrationStartedAt == nil)
                .accessibilityAddTraits(profile.yellowModeValue == mode ? .isSelected : [])
            }
            if isRunning || profile.calibrationStartedAt == nil {
                Text("You can choose when the calibration ends.")
                    .font(theme.body(.caption))
                    .foregroundStyle(theme.colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(theme.body(.subheadline))
                .foregroundStyle(theme.colors.textSecondary)
            Spacer()
            Text(value)
                .font(theme.number(.subheadline))
                .foregroundStyle(theme.colors.textPrimary)
        }
    }
}
