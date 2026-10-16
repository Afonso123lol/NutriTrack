import SwiftUI
import CoreData

struct MealRowView: View {
    @Environment(\.theme) private var theme
    @Environment(\.managedObjectContext) private var ctx
    @ObservedObject var entry: FoodEntry
    @State private var isRepeating = false
    @State private var isEditing = false
    @State private var isChangingTime = false
    @State private var isConfirmingDelete = false

    private var name: String { entry.dishName ?? "Meal" }
    private var time: String { entry.timestamp?.formatted(date: .omitted, time: .shortened) ?? "" }

    var body: some View {
        HStack(spacing: 4) {
            NavigationLink(destination: MealDetailView(entry: entry)) {
                HStack(spacing: 12) {
                    thumbnail
                    VStack(alignment: .leading, spacing: 4) {
                        Text(name)
                            .font(theme.body(.subheadline).weight(.semibold))
                            .foregroundStyle(theme.colors.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text("\(time) · \(Text("P").foregroundStyle(theme.colors.protein)) \(grams(entry.proteinG)) · \(Text("C").foregroundStyle(theme.colors.carbs)) \(grams(entry.carbsG)) · \(Text("F").foregroundStyle(theme.colors.fat)) \(grams(entry.fatG))")
                            .font(theme.meta(.caption))
                            .foregroundStyle(theme.colors.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 4)
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(String(format: "%.0f", entry.calories))
                            .font(theme.number(.headline))
                            .foregroundStyle(theme.colors.textPrimary)
                        Text("kcal")
                            .font(theme.meta(.caption2))
                            .foregroundStyle(theme.colors.textSecondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(name)
            .accessibilityValue(String(format: "%@, %.0f kilocalories, %.0f grams protein, %.0f grams carbs, %.0f grams fat",
                                       time, entry.calories, entry.proteinG, entry.carbsG, entry.fatG))

            Menu {
                Button { isRepeating = true } label: { Label("Log again", systemImage: "arrow.counterclockwise") }
                Button { isEditing = true } label: { Label("Edit", systemImage: "pencil") }
                Button { isChangingTime = true } label: { Label("Change time", systemImage: "clock") }
                Button(role: .destructive) { isConfirmingDelete = true } label: { Label("Delete", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.colors.textSecondary)
                    .frame(width: 36, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Actions for \(name)")
        }
        .sheet(isPresented: $isRepeating) {
            LogAgainSheet(entry: entry)
        }
        .sheet(isPresented: $isEditing) {
            MealEditSheet(analysis: entry.analysis) { entry.applyEdit($0, in: ctx) }
        }
        .sheet(isPresented: $isChangingTime) {
            DateWheelSheet(title: "Eaten at", date: entry.timestamp ?? Date(), range: Date.distantPast...Date(),
                           components: [.date, .hourAndMinute], confirmTitle: "Save") {
                entry.changeTime(to: $0, in: ctx)
            }
        }
        .alert("Delete this meal?", isPresented: $isConfirmingDelete) {
            Button("Delete", role: .destructive) { entry.remove(from: ctx) }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func grams(_ value: Double) -> String {
        String(format: "%.0f", value)
    }

    @ViewBuilder private var thumbnail: some View {
        let shape = RoundedRectangle(cornerRadius: min(theme.shape.controlRadius, 14), style: .continuous)
        if let data = entry.thumbnailData ?? entry.photoData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(shape)
        } else {
            Image(systemName: "fork.knife")
                .font(.subheadline)
                .foregroundStyle(theme.colors.textMuted)
                .frame(width: 56, height: 56)
                .background(theme.colors.surfaceElevated, in: shape)
        }
    }
}
