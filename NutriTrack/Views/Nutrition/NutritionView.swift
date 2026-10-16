import SwiftUI
import CoreData

struct NutritionView: View {
    let profile: UserProfile
    @Environment(\.theme) private var theme
    @Environment(\.managedObjectContext) private var ctx
    @EnvironmentObject private var pendingStore: PendingMealStore
    @AppStorage("nutritionShowsRemaining") private var showsRemaining = true
    @State private var showCamera = false
    @State private var scrollOffset: CGFloat = 0
    @State private var pendingDeleteSupplement: SupplementLog?

    @FetchRequest private var todayFood: FetchedResults<FoodEntry>
    @FetchRequest private var todaySupLogs: FetchedResults<SupplementLog>
    @FetchRequest private var templates: FetchedResults<SupplementTemplate>

    init(profile: UserProfile) {
        self.profile = profile
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        let pred = NSPredicate(format: "timestamp >= %@ AND timestamp < %@", start as NSDate, end as NSDate)
        _todayFood = FetchRequest(entity: FoodEntry.entity(),
                                  sortDescriptors: [NSSortDescriptor(keyPath: \FoodEntry.timestamp, ascending: false)],
                                  predicate: pred)
        _todaySupLogs = FetchRequest(entity: SupplementLog.entity(),
                                     sortDescriptors: [NSSortDescriptor(keyPath: \SupplementLog.timestamp, ascending: false)],
                                     predicate: pred)
        _templates = FetchRequest(entity: SupplementTemplate.entity(), sortDescriptors: [])
    }

    private func supplementNutrients(for log: SupplementLog) -> NutritionAnalysis? {
        if let snapshot = log.snapshotNutrients { return snapshot }
        guard let t = templates.first(where: { $0.id?.uuidString == log.templateID }) else { return nil }
        return t.nutrientsScaled(by: log.doses)
    }

    private func supplementName(_ log: SupplementLog) -> String {
        log.name ?? templates.first(where: { $0.id?.uuidString == log.templateID })?.name ?? "Supplement"
    }

    var body: some View {
        NavigationStack {
            let targets = profile.macroTargets
            let total = NutritionAnalysis.sum(todayFood.map(\.analysis) + todaySupLogs.compactMap(supplementNutrients))
            let day = TargetService.dayTargets(for: profile,
                                               plannedMinutes: TrainingService.plannedAerobicMinutes(on: Date(), in: ctx),
                                               hardEffort: TrainingService.hasHardSession(on: Date(), in: ctx))
            ScrollView {
                LazyVStack(spacing: 14) {
                    header(eaten: total.calories, target: targets.calories)
                        .padding(.top, ScreenBackdrop.headroom(for: theme.style.backdrop))

                    VStack(alignment: .leading, spacing: 14) {
                        macroRow("P", "Protein", value: total.proteinG, target: targets.proteinG,
                                 color: theme.colors.protein,
                                 geometry: .make(value: total.proteinG, target: targets.proteinG))
                        macroRow("C", "Carbs", value: total.carbsG, target: day.carbsG,
                                 color: theme.colors.carbs,
                                 geometry: day.carbMinimumG.map {
                                     .make(value: total.carbsG, target: day.carbsG, minimum: $0)
                                 } ?? .make(value: total.carbsG, target: day.carbsG))
                        macroRow("F", "Fat", value: total.fatG, target: day.fatG,
                                 color: theme.colors.fat,
                                 geometry: .make(value: total.fatG, target: day.fatG))
                        if let minimum = day.carbMinimumG {
                            Text(String(format: day.isShort
                                        ? "Training day: at least %.0f g of carbs would be ideal, which today's calories do not allow."
                                        : "Training day: at least %.0f g of carbs; fat comes down to make room.", minimum))
                                .font(theme.body(.caption))
                                .foregroundStyle(day.isShort ? theme.colors.warning : theme.colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .themedCard()

                    WaterRow()
                        .themedCard(padding: 12)

                    if !pendingStore.items.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            EyebrowText("New meals")
                            ForEach(pendingStore.items) { item in
                                PendingMealRow(
                                    item: item,
                                    onSave: { analysis, image, note, wasEdited in
                                        FoodEntry.create(from: analysis, image: image, note: note,
                                                         timestamp: item.eatenAt, wasEdited: wasEdited, in: ctx)
                                        pendingStore.remove(item)
                                    },
                                    onRetry: { pendingStore.retry(item) },
                                    onDiscard: { pendingStore.remove(item) }
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .themedCard()
                    }

                    if todayFood.isEmpty && todaySupLogs.isEmpty && pendingStore.items.isEmpty {
                        EmptyStateCard(
                            icon: "fork.knife",
                            title: "No meals yet today",
                            message: "Point the camera at your plate and the app does the rest.",
                            actionTitle: "Log a meal",
                            action: { showCamera = true }
                        )
                    }

                    if !todayFood.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            EyebrowText("Meals today")
                            ForEach(todayFood) { entry in
                                MealRowView(entry: entry)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .themedCard()
                    }

                    if !todaySupLogs.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            EyebrowText("Supplements today")
                            ForEach(todaySupLogs) { log in
                                supplementRow(log)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .themedCard()
                    }

                    VStack(spacing: 0) {
                        link("Micronutrients", icon: "chart.bar.fill") {
                            MicronutrientsView(foodEntries: Array(todayFood), supplementLogs: Array(todaySupLogs),
                                               templates: Array(templates), profile: profile)
                        }
                        link("Advanced metrics", icon: "slider.horizontal.3") {
                            AdvancedMetricsView(total: total)
                        }
                        link("Supplements", icon: "pills.fill") {
                            SupplementsView()
                        }
                        link("History", icon: "clock.arrow.circlepath") {
                            HistoryView()
                        }
                    }
                    .themedCard(padding: 12)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 110)
            }
            .scrollIndicators(.hidden)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, offset in
                scrollOffset = offset
            }
            .background(alignment: .top) {
                ScreenBackdrop(tone: theme.colors.diet)
                    .offset(y: -max(0, scrollOffset))
            }
            .background(theme.colors.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .statusBarScrim(scrollOffset: scrollOffset)
            .alert("Delete this supplement?",
                   isPresented: Binding(get: { pendingDeleteSupplement != nil },
                                        set: { if !$0 { pendingDeleteSupplement = nil } })) {
                Button("Delete", role: .destructive) {
                    if let log = pendingDeleteSupplement {
                        let day = log.timestamp ?? Date()
                        ctx.delete(log)
                        try? ctx.save()
                        EvaluationService.refreshClosedDay(containing: day, in: ctx)
                    }
                    pendingDeleteSupplement = nil
                }
                Button("Cancel", role: .cancel) { pendingDeleteSupplement = nil }
            }
            .sheet(isPresented: $showCamera) {
                CameraView(profile: profile)
            }
        }
    }

    private func header(eaten: Double, target: Double) -> some View {
        let headline = NutritionHeadline.make(eaten: eaten, target: target, showsRemaining: showsRemaining)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Nutrition · \(Date().formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))")
                .font(theme.meta(.caption).weight(.semibold))
                .tracking(theme.typography.eyebrowTracking)
                .textCase(theme.typography.isEyebrowUppercase ? .uppercase : nil)
                .foregroundStyle(theme.colors.diet)
            Button {
                showsRemaining.toggle()
            } label: {
                Text(headline.title)
                    .font(theme.display(.largeTitle))
                    .tracking(theme.typography.titleTracking)
                    .foregroundStyle(theme.colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.numericText())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)
            .accessibilityHint("Switches between calories left and calories eaten")
            TargetBar(geometry: .make(value: eaten, target: target), color: theme.colors.diet, isProminent: true)
            Text(headline.detail)
                .font(theme.meta(.caption))
                .foregroundStyle(theme.colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func macroRow(_ letter: String, _ name: String, value: Double, target: Double,
                          color: Color, geometry: TargetBarGeometry) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                MacroDot(letter: letter, color: color)
                Text(name)
                    .font(theme.body(.subheadline))
                    .foregroundStyle(theme.colors.textPrimary)
                Spacer()
                Text(String(format: "%.0f", value))
                    .font(theme.number(.subheadline))
                    .foregroundStyle(theme.colors.textPrimary)
                    .contentTransition(.numericText())
                Text(String(format: "/ %.0f g", target))
                    .font(theme.meta(.caption))
                    .foregroundStyle(theme.colors.textSecondary)
            }
            TargetBar(geometry: geometry, color: color)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityValue(String(format: "%.0f of %.0f grams", value, target))
    }

    private func supplementRow(_ log: SupplementLog) -> some View {
        let name = supplementName(log)
        return HStack(spacing: 10) {
            Image(systemName: "pills.fill")
                .font(.subheadline)
                .foregroundStyle(theme.colors.accent)
                .frame(width: 24)
            Text(name)
                .font(theme.body(.subheadline).weight(.semibold))
                .foregroundStyle(theme.colors.textPrimary)
                .lineLimit(2)
            Spacer(minLength: 8)
            Text(log.timestamp ?? Date(), style: .time)
                .font(theme.meta(.caption))
                .foregroundStyle(theme.colors.textSecondary)
            Menu {
                Button(role: .destructive) { pendingDeleteSupplement = log } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.colors.textSecondary)
                    .frame(width: 36, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Actions for \(name)")
        }
    }

    private func link<Destination: View>(_ title: String, icon: String,
                                         @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(theme.colors.accent)
                    .frame(width: 24)
                Text(title)
                    .font(theme.body(.subheadline))
                    .foregroundStyle(theme.colors.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.colors.textMuted)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
