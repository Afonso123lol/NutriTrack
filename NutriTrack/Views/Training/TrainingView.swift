import SwiftUI
import CoreData

struct TrainingView: View {
    @ObservedObject var profile: UserProfile
    @Environment(\.theme) private var theme
    @Environment(\.managedObjectContext) private var ctx

    @FetchRequest(entity: TrainingProfile.entity(), sortDescriptors: [])
    private var profiles: FetchedResults<TrainingProfile>
    @FetchRequest private var weeks: FetchedResults<TrainingWeek>
    @FetchRequest private var planned: FetchedResults<PlannedSession>
    @FetchRequest private var sessions: FetchedResults<TrainingSession>
    @FetchRequest private var checkIns: FetchedResults<DailyCheckIn>

    @State private var showSetup = false
    @State private var aerobicLog: AerobicLog?
    @State private var strengthLog: PlannedSession?
    @State private var pendingDelete: TrainingSession?

    private let weekStart: Date

    struct AerobicLog: Identifiable {
        let id = UUID()
        let plannedID: UUID?
        let modality: Modality
        let minutes: Double
    }

    init(profile: UserProfile) {
        self.profile = profile
        let start = TargetService.weekStart(for: Date())
        let end = start.addingTimeInterval(7 * TrainingService.day)
        weekStart = start
        _weeks = FetchRequest(entity: TrainingWeek.entity(), sortDescriptors: [],
                              predicate: NSPredicate(format: "weekStart == %@", start as NSDate))
        _planned = FetchRequest(entity: PlannedSession.entity(),
                                sortDescriptors: [NSSortDescriptor(keyPath: \PlannedSession.dayIndex, ascending: true)],
                                predicate: NSPredicate(format: "weekStart == %@", start as NSDate))
        _sessions = FetchRequest(entity: TrainingSession.entity(),
                                 sortDescriptors: [NSSortDescriptor(keyPath: \TrainingSession.startedAt, ascending: false)],
                                 predicate: NSPredicate(format: "startedAt >= %@ AND startedAt < %@",
                                                        start as NSDate, end as NSDate))
        _checkIns = FetchRequest(entity: DailyCheckIn.entity(), sortDescriptors: [],
                                 predicate: DailyCheckIn.todayPredicate())
    }

    private var bmi: Double { BodyMetrics.bmi(weightKg: profile.weightKg, heightCm: profile.heightCm) }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    ScreenHeader(eyebrow: "Plan", title: "Training") {
                        if profiles.first != nil {
                            Button { showSetup = true } label: {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.subheadline)
                                    .foregroundStyle(theme.colors.textSecondary)
                                    .frame(width: 36, height: 36)
                                    .background(theme.colors.surfaceElevated, in: Circle())
                            }
                            .accessibilityLabel("Training setup")
                        }
                    }
                    content
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(theme.colors.background, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .sheet(isPresented: $showSetup) { TrainingSetupView(user: profile) }
            .sheet(item: $aerobicLog) { log in
                LogAerobicSheet(plannedID: log.plannedID, modality: log.modality, minutes: log.minutes)
            }
            .sheet(item: $strengthLog) { session in
                let today = Calendar.current.startOfDay(for: Date())
                let applied = TrainingService.sessionPlan(
                    session, profile: profile, color: TrainingService.color(on: Date(), in: ctx),
                    badDays: TrainingService.badDays(from: TargetService.weekStart(for: Date()),
                                                     to: today.addingTimeInterval(TrainingService.day), in: ctx),
                    now: Date(), in: ctx).applied
                let reserve = StrengthProgram.targetReserve(weekNumber: weeks.first.map { TrainingService.weekNumber(of: $0, in: ctx) } ?? 1)
                LogStrengthSheet(plannedID: session.id,
                                 exercises: StrengthProgram.exercises(hasGym: profiles.first?.hasGym ?? false),
                                 sets: max(applied.strengthSets, 1),
                                 reserve: (reserve.lowerBound + applied.extraRepsInReserve)...(reserve.upperBound + applied.extraRepsInReserve),
                                 estimatedMinutes: session.targetMinutes)
            }
            .alert("Delete this session?",
                   isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
                Button("Delete", role: .destructive) {
                    if let session = pendingDelete { TrainingService.delete(session, in: ctx) }
                    pendingDelete = nil
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            }
            .onAppear { TrainingService.ensureWeek(user: profile, in: ctx) }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let training = profiles.first {
            switch TrainingService.gate(training, user: profile) {
            case .blocked:
                blockedCard(training)
            case .walkingOnly:
                noteCard("With a BMI of 35 or more, talk to a doctor before you start. Until you confirm that you did, the plan is walking only, with no strength work.",
                         training: training)
                plan
            case .full:
                plan
            }
        } else {
            EmptyStateCard(
                icon: "figure.hiking",
                title: "No training plan yet",
                message: "A short health check and three questions, and the app builds your first week.",
                actionTitle: "Set up training",
                action: { showSetup = true }
            )
        }
    }

    @ViewBuilder
    private var plan: some View {
        if let week = weeks.first {
            let color = TrainingService.color(on: Date(), in: ctx)
            let badDays = TrainingService.badDays(from: weekStart, to: Calendar.current.startOfDay(for: Date()).addingTimeInterval(TrainingService.day), in: ctx)
            weekCard(week)
            todayCard(color: color, badDays: badDays)
            daysCard
            loadCard
            Text("Stop and get medical help for chest pain or pressure, unusual shortness of breath, fainting, palpitations, or very dark urine after effort. Stop the session for sharp joint pain, or pain that changes how you walk or lasts more than 48 hours. General training information, not medical advice.")
                .font(theme.body(.caption))
                .foregroundStyle(theme.colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text("Building your week…")
                .font(theme.body(.subheadline))
                .foregroundStyle(theme.colors.textSecondary)
                .themedCard()
        }
    }

    private func blockedCard(_ training: TrainingProfile) -> some View {
        noteCard("You switched on at least one item in the health check. Talk to a doctor before you start; the app builds your plan once you confirm that you did.",
                 training: training)
    }

    private func noteCard(_ text: String, training: TrainingProfile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowText("Before you start")
            Text(text)
                .font(theme.body(.subheadline))
                .foregroundStyle(theme.colors.textPrimary)
            Button("I talked to a doctor and was cleared") {
                training.doctorCleared = true
                try? ctx.save()
                TrainingService.regenerateWeek(user: profile, in: ctx)
            }
            .buttonStyle(.bordered)
            .font(theme.body(.subheadline))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .themedCard()
    }

    private func weekCard(_ week: TrainingWeek) -> some View {
        let done = sessions.filter { $0.kind != "strength" }.reduce(0) { $0 + $1.durationMin }
        let progress = week.targetMinutes > 0 ? min(done / week.targetMinutes, 1) : 0
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                EyebrowText(week.phase == "base" ? "Base" : "Transition")
                Spacer()
                Text(week.isDeload ? "Lighter week" : "Week \(week.weekInBlock) of the block")
                    .font(theme.body(.caption))
                    .foregroundStyle(theme.colors.textSecondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "%.0f", done))
                    .font(theme.number(34))
                    .foregroundStyle(theme.colors.textPrimary)
                Text(String(format: "/ %.0f min easy", week.targetMinutes))
                    .font(theme.number(.subheadline))
                    .foregroundStyle(theme.colors.textSecondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(theme.colors.textMuted.opacity(0.2)).frame(height: 8)
                    RoundedRectangle(cornerRadius: 4).fill(theme.colors.readiness)
                        .frame(width: geo.size.width * progress, height: 8)
                }
            }
            .frame(height: 8)
            .accessibilityHidden(true)
            Text(decisionText(week))
                .font(theme.body(.caption))
                .foregroundStyle(theme.colors.textSecondary)
        }
        .themedCard()
    }

    private func decisionText(_ week: TrainingWeek) -> String {
        switch WeekDecision(rawValue: week.decision ?? "") ?? .start {
        case .start: return "Your first week. Everything easy: you should be able to speak in full sentences."
        case .restart: return "More than four weeks without training: a fresh start at half of your previous volume."
        case .returnAfterOneWeek: return "Back after more than a week off: 80% of your last full week."
        case .returnAfterTwoWeeks: return "Back after more than two weeks off: 65% of your last full week."
        case .progress: return String(format: "You did %.0f minutes last week, so this one goes up a little.", week.basisMinutes)
        case .repeatWeek: return "Last week was not completed, so this one repeats it."
        case .reduce: return "Two weeks well under the plan: the plan comes down to what you actually did. Fewer training days may fit your life better."
        case .lowReadiness: return "Three low days last week: same volume, no increase."
        case .deload: return "Planned lighter week: same days, shorter sessions."
        case .afterDeload: return "New block, starting from the second week of the previous one."
        }
    }

    private func todayCard(color: DayColor, badDays: Int) -> some View {
        let today = Int16(TrainingService.dayIndex(of: Date()))
        let todays = planned.filter { $0.dayIndex == today }.sorted { $0.kind != "strength" && $1.kind == "strength" }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                EyebrowText("Today")
                Spacer()
                Text(checkIns.isEmpty ? "No check-in yet" : color.label)
                    .font(theme.body(.caption).weight(.semibold))
                    .foregroundStyle(color.tint(in: theme))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(color.tint(in: theme).opacity(0.15), in: Capsule())
            }
            if todays.isEmpty {
                Text("Nothing planned. Rest, or log anything you do anyway.")
                    .font(theme.body(.subheadline))
                    .foregroundStyle(theme.colors.textSecondary)
            }
            ForEach(todays) { session in
                plannedRow(session, color: color, badDays: badDays)
            }
            Button {
                aerobicLog = AerobicLog(plannedID: nil, modality: .walk, minutes: 30)
            } label: {
                Label("Log another session", systemImage: "plus")
            }
            .buttonStyle(.bordered)
            .font(theme.body(.subheadline))
        }
        .themedCard()
    }

    private func plannedRow(_ session: PlannedSession, color: DayColor, badDays: Int) -> some View {
        let kind = SessionKind(rawValue: session.kind ?? "") ?? .easy
        let modality = Modality(rawValue: session.modality ?? "") ?? .walk
        let adjusted = TrainingService.sessionPlan(session, profile: profile, color: color, badDays: badDays,
                                                   now: Date(), in: ctx).applied
        let isDone = sessions.contains { $0.plannedSessionID == session.id }
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: isDone ? "checkmark.circle.fill" : modality.icon)
                    .foregroundStyle(isDone ? theme.colors.success : theme.colors.readiness)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title(kind: kind, modality: modality))
                        .font(theme.body(.subheadline).weight(.semibold))
                        .foregroundStyle(theme.colors.textPrimary)
                    Text(detail(kind: kind, adjusted: adjusted))
                        .font(theme.body(.caption))
                        .foregroundStyle(theme.colors.textSecondary)
                }
                Spacer()
                if !isDone {
                    Button("Log") { startLog(session, minutes: adjusted.targetMinutes) }
                    .buttonStyle(.bordered)
                    .font(theme.body(.subheadline))
                }
            }
            if let note = adjusted.note {
                Text(note)
                    .font(theme.body(.caption))
                    .foregroundStyle(theme.colors.warning)
            }
        }
    }

    private func startLog(_ session: PlannedSession, minutes: Double) {
        if session.kind == SessionKind.strength.rawValue {
            strengthLog = session
        } else {
            aerobicLog = AerobicLog(plannedID: session.id, modality: Modality(rawValue: session.modality ?? "") ?? .walk,
                                    minutes: minutes)
        }
    }

    private func title(kind: SessionKind, modality: Modality) -> String {
        switch kind {
        case .easy: return "Easy \(modality.label.lowercased())"
        case .long: return "Long \(modality.label.lowercased())"
        case .strength: return "Strength"
        }
    }

    private func detail(kind: SessionKind, adjusted: AdjustedSession) -> String {
        if adjusted.isRest { return kind == .strength ? "Not today" : "Rest" }
        if kind == .strength {
            return "\(adjusted.strengthSets) set\(adjusted.strengthSets == 1 ? "" : "s") of 6 exercises, 10–15 reps"
        }
        return String(format: "%.0f min, effort 4 or less", adjusted.targetMinutes)
    }

    private var daysCard: some View {
        let names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        return VStack(alignment: .leading, spacing: 10) {
            EyebrowText("This week")
            ForEach(0..<7, id: \.self) { index in
                let dayPlan = planned.filter { $0.dayIndex == Int16(index) }.sorted { $0.kind != "strength" && $1.kind == "strength" }
                let dayDone = sessions.filter { TrainingService.dayIndex(of: $0.startedAt ?? Date()) == index }
                HStack(alignment: .top, spacing: 10) {
                    Text(names[index])
                        .font(theme.body(.caption).weight(.semibold))
                        .foregroundStyle(theme.colors.textSecondary)
                        .frame(width: 34, alignment: .leading)
                    VStack(alignment: .leading, spacing: 4) {
                        if dayPlan.isEmpty && dayDone.isEmpty {
                            Text("Rest")
                                .font(theme.body(.caption))
                                .foregroundStyle(theme.colors.textMuted)
                        }
                        ForEach(dayPlan) { session in
                            HStack(spacing: 8) {
                                Text(planLine(session))
                                    .font(theme.body(.caption))
                                    .foregroundStyle(theme.colors.textPrimary)
                                if sessions.contains(where: { $0.plannedSessionID == session.id }) {
                                    Image(systemName: "checkmark")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(theme.colors.success)
                                        .accessibilityLabel("Done")
                                } else {
                                    Button("Log") { startLog(session, minutes: session.targetMinutes) }
                                        .buttonStyle(.borderless)
                                        .font(theme.body(.caption).weight(.semibold))
                                }
                            }
                        }
                        ForEach(dayDone) { session in
                            doneLine(session)
                        }
                    }
                    Spacer()
                }
            }
        }
        .themedCard()
    }

    private func planLine(_ session: PlannedSession) -> String {
        let kind = SessionKind(rawValue: session.kind ?? "") ?? .easy
        let modality = Modality(rawValue: session.modality ?? "") ?? .walk
        if kind == .strength { return "Strength · \(session.strengthSets) set\(session.strengthSets == 1 ? "" : "s")" }
        return String(format: "%@ · %.0f min", title(kind: kind, modality: modality), session.targetMinutes)
    }

    private func doneLine(_ session: TrainingSession) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(theme.colors.success)
                .accessibilityHidden(true)
            Text(String(format: "%@ · %.0f min · effort %d", (Modality(rawValue: session.modality ?? "") ?? .other).label,
                        session.durationMin, session.rpe))
                .font(theme.number(.caption))
                .foregroundStyle(theme.colors.textSecondary)
            Button {
                pendingDelete = session
            } label: {
                Image(systemName: "trash")
                    .font(.caption2)
                    .foregroundStyle(theme.colors.danger)
                    .frame(width: 32, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete session")
        }
    }

    private var loadCard: some View {
        let load = TrainingService.weekLoad(in: ctx)
        return VStack(alignment: .leading, spacing: 10) {
            EyebrowText("Load this week")
            HStack(spacing: 10) {
                StatCard(label: "Minutes", value: String(format: "%.0f", load.aerobicMinutes))
                StatCard(label: "Load", value: String(format: "%.0f", load.load))
                StatCard(label: "Climb", value: String(format: "%.0f m", load.elevationM))
            }
            Text("Load is effort times minutes, summed over the week.")
                .font(theme.body(.caption))
                .foregroundStyle(theme.colors.textSecondary)
            ForEach(load.warnings, id: \.self) { warning in
                Text(warning.text)
                    .font(theme.body(.caption))
                    .foregroundStyle(theme.colors.warning)
            }
        }
        .themedCard()
    }
}
