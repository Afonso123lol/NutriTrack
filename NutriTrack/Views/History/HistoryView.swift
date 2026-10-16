import SwiftUI
import CoreData

struct HistoryView: View {
    @Environment(\.theme) private var theme
    @State private var days = FoodEntry.historyPageDays

    var body: some View {
        HistoryList(days: days) { days += FoodEntry.historyPageDays }
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .hidesCaptureButton()
    }
}

private struct HistoryList: View {
    let onShowEarlier: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.managedObjectContext) private var ctx
    @FetchRequest private var entries: FetchedResults<FoodEntry>
    private let cutoff: Date

    init(days: Int, onShowEarlier: @escaping () -> Void) {
        self.onShowEarlier = onShowEarlier
        let cutoff = FoodEntry.historyCutoff(days: days)
        self.cutoff = cutoff
        _entries = FetchRequest(entity: FoodEntry.entity(),
                                sortDescriptors: [NSSortDescriptor(keyPath: \FoodEntry.timestamp, ascending: false)],
                                predicate: NSPredicate(format: "timestamp >= %@", cutoff as NSDate))
    }

    private var hasEarlier: Bool {
        let request = FoodEntry.fetchRequest()
        request.predicate = NSPredicate(format: "timestamp < %@", cutoff as NSDate)
        return ((try? ctx.count(for: request)) ?? 0) > 0
    }

    private var grouped: [(String, [FoodEntry])] {
        let f = DateFormatter(); f.dateStyle = .medium; f.locale = Locale(identifier: "en_GB")
        let d = Dictionary(grouping: entries) { f.string(from: $0.timestamp ?? Date()) }
        return d.sorted {
            ($0.value.first?.timestamp ?? .distantPast) > ($1.value.first?.timestamp ?? .distantPast)
        }
    }

    var body: some View {
        let hasEarlier = self.hasEarlier
        ScrollView {
            LazyVStack(spacing: 14) {
                if entries.isEmpty && !hasEarlier {
                    EmptyStateCard(
                        icon: "fork.knife",
                        title: "No meals yet",
                        message: "Your meals will appear here after logging."
                    )
                }

                ForEach(grouped, id: \.0) { day, dayEntries in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            EyebrowText(day)
                            Spacer()
                            Text(String(format: "%.0f kcal", dayEntries.reduce(0) { $0 + $1.calories }))
                                .font(theme.number(.subheadline))
                                .foregroundStyle(theme.colors.textSecondary)
                        }
                        ForEach(dayEntries) { entry in
                            MealRowView(entry: entry)
                        }
                    }
                    .themedCard()
                }

                if hasEarlier {
                    Button("Show earlier") { onShowEarlier() }
                        .buttonStyle(.bordered)
                        .font(theme.body(.subheadline))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 110)
        }
        .scrollIndicators(.hidden)
    }
}
