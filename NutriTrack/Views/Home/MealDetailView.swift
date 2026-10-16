import SwiftUI
import CoreData

struct MealDetailView: View {
    @ObservedObject var entry: FoodEntry
    @Environment(\.theme) private var theme
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @State private var photo: UIImage?
    @State private var showEdit = false
    @State private var showLogAgain = false
    @State private var confirmDelete = false

    private var when: String {
        entry.timestamp?.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute()) ?? "Meal"
    }

    var body: some View {
        MealPhotoScaffold(image: photo) {
            VStack(alignment: .leading, spacing: 8) {
                EyebrowText(when)
                Text(entry.dishName ?? "Meal")
                    .font(theme.display(.title2))
                    .foregroundStyle(theme.colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(String(format: "%.0f", entry.calories))
                        .font(theme.number(34))
                        .foregroundStyle(theme.colors.textPrimary)
                    Text("kcal")
                        .font(theme.meta(.subheadline))
                        .foregroundStyle(theme.colors.textSecondary)
                    if entry.wasEdited {
                        Text("Edited")
                            .font(theme.meta(.caption2).weight(.semibold))
                            .foregroundStyle(theme.colors.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(theme.colors.surfaceElevated, in: Capsule())
                            .padding(.leading, 6)
                    }
                }
                if let comment = entry.aiComment, !comment.isEmpty {
                    Text(comment)
                        .font(theme.body(.subheadline))
                        .foregroundStyle(theme.colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let note = entry.note, !note.isEmpty {
                    Text(note)
                        .font(theme.body(.caption))
                        .foregroundStyle(theme.colors.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 10) {
                    Button { showLogAgain = true } label: {
                        Label("Log again", systemImage: "arrow.counterclockwise")
                    }
                    Button { showEdit = true } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                }
                .buttonStyle(.themedOutline)
                .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            MealFactsView(analysis: entry.analysis)

            Text("Values are AI estimates based on visual analysis. Actual nutrition may vary.")
                .font(theme.body(.caption))
                .foregroundStyle(theme.colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .hidesCaptureButton()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(theme.colors.danger)
                }
                .accessibilityLabel("Delete \(entry.dishName ?? "meal")")
            }
        }
        .alert("Delete this meal?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                entry.remove(from: ctx)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showEdit) {
            MealEditSheet(analysis: entry.analysis) { entry.applyEdit($0, in: ctx) }
        }
        .sheet(isPresented: $showLogAgain) {
            LogAgainSheet(entry: entry)
        }
        .task(id: entry.objectID) {
            if photo == nil, let thumbnail = entry.thumbnailData { photo = UIImage(data: thumbnail) }
            if let data = entry.photoData, let full = await UIImage(data: data)?.byPreparingForDisplay() {
                photo = full
            }
        }
    }
}
