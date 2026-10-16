import SwiftUI

struct AnalysisPreviewSheet: View {
    let image: UIImage?
    let note: String?
    let onSave: (NutritionAnalysis, Bool) -> Void
    let onDiscard: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var current: NutritionAnalysis
    @State private var wasEdited = false
    @State private var showEdit = false

    init(analysis: NutritionAnalysis, image: UIImage?, note: String?,
         onSave: @escaping (NutritionAnalysis, Bool) -> Void, onDiscard: @escaping () -> Void) {
        self.image = image
        self.note = note
        self.onSave = onSave
        self.onDiscard = onDiscard
        _current = State(initialValue: analysis)
    }

    var body: some View {
        NavigationStack {
            MealPhotoScaffold(image: image) {
                VStack(alignment: .leading, spacing: 8) {
                    EyebrowText(wasEdited ? "Review before saving · edited" : "Review before saving")
                    Text(current.dishName)
                        .font(theme.display(.title2))
                        .foregroundStyle(theme.colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(String(format: "%.0f", current.calories))
                            .font(theme.number(34))
                            .foregroundStyle(theme.colors.textPrimary)
                            .contentTransition(.numericText())
                        Text("kcal")
                            .font(theme.meta(.subheadline))
                            .foregroundStyle(theme.colors.textSecondary)
                    }
                    if let comment = current.comment, !comment.isEmpty {
                        Text(comment)
                            .font(theme.body(.subheadline))
                            .foregroundStyle(theme.colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let note, !note.isEmpty {
                        Text(note)
                            .font(theme.body(.caption))
                            .foregroundStyle(theme.colors.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let flags = current.validationFlags, !flags.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        EyebrowText("Adjustments")
                        ForEach(flags, id: \.self) { flag in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(theme.colors.warning)
                                Text(flag)
                                    .font(theme.body(.caption))
                                    .foregroundStyle(theme.colors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .themedCard()
                }

                MealFactsView(analysis: current)

                Text(image == nil ? "Values are AI estimates based on your description. Actual nutrition may vary."
                                  : "Values are AI estimates based on visual analysis. Actual nutrition may vary.")
                    .font(theme.body(.caption))
                    .foregroundStyle(theme.colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                HStack(spacing: 10) {
                    Button("Edit") { showEdit = true }
                        .buttonStyle(.themedOutline)
                    Button("Save") {
                        onSave(current, wasEdited)
                        dismiss()
                    }
                    .buttonStyle(.themedPrimary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(theme.colors.background)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Discard", role: .destructive) {
                        onDiscard()
                        dismiss()
                    }
                    .foregroundStyle(theme.colors.danger)
                }
            }
            .sheet(isPresented: $showEdit) {
                MealEditSheet(analysis: current) { edited in
                    current = edited
                    wasEdited = true
                }
            }
        }
    }
}
