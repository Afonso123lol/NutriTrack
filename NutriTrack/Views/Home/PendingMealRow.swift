import SwiftUI

struct PendingMealRow: View {
    @Environment(\.theme) private var theme
    @ObservedObject var item: PendingMealItem
    @ObservedObject private var jobStore = ModelJobStore.shared
    let onSave: (NutritionAnalysis, UIImage?, String?, Bool) -> Void
    let onRetry: () -> Void
    let onDiscard: () -> Void

    @State private var showPreview = false

    private var attempt: Int? {
        let kind = ModelJobKind.mealAnalysis(pendingItemID: item.id)
        return jobStore.jobs.first { $0.kind == kind }?.attempt
    }

    var body: some View {
        Group {
            switch item.status {
            case .loading:
                HStack(spacing: 12) {
                    thumbnail
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Analysing your meal")
                            .font(theme.body(.subheadline).weight(.semibold))
                            .foregroundStyle(theme.colors.textPrimary)
                        TimelineView(.periodic(from: .now, by: 30)) { context in
                            Text("\(PendingMealText.elapsed(since: item.createdAt, now: context.date)) · \(PendingMealText.waiting(attempt: attempt))")
                                .font(theme.meta(.caption))
                                .foregroundStyle(theme.colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    ProgressView()
                        .tint(theme.colors.textSecondary)
                }
                .accessibilityElement(children: .combine)

            case .done(let result):
                Button { showPreview = true } label: {
                    HStack(spacing: 12) {
                        thumbnail
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ready to review")
                                .font(theme.meta(.caption).weight(.semibold))
                                .foregroundStyle(theme.colors.accent)
                            Text(result.dishName)
                                .font(theme.body(.subheadline).weight(.semibold))
                                .foregroundStyle(theme.colors.textPrimary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Text(String(format: "%.0f kcal · P %.0f · C %.0f · F %.0f",
                                        result.calories, result.proteinG, result.carbsG, result.fatG))
                                .font(theme.meta(.caption))
                                .foregroundStyle(theme.colors.textSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.colors.textMuted)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showPreview) {
                    AnalysisPreviewSheet(
                        analysis: result,
                        image: item.image,
                        note: item.note,
                        onSave: { edited, wasEdited in onSave(edited, item.image, item.note, wasEdited) },
                        onDiscard: onDiscard
                    )
                }

            case .failed(let message):
                HStack(alignment: .top, spacing: 12) {
                    thumbnail
                    VStack(alignment: .leading, spacing: 4) {
                        Label {
                            Text("Analysis failed")
                                .font(theme.body(.subheadline).weight(.semibold))
                                .foregroundStyle(theme.colors.textPrimary)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(theme.colors.warning)
                        }
                        Text(message)
                            .font(theme.body(.caption))
                            .foregroundStyle(theme.colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 20) {
                            Button("Retry") { onRetry() }
                                .font(theme.body(.subheadline).weight(.semibold))
                                .foregroundStyle(theme.colors.accent)
                            Button("Dismiss") { onDiscard() }
                                .font(theme.body(.subheadline))
                                .foregroundStyle(theme.colors.textSecondary)
                        }
                        .buttonStyle(.borderless)
                        .frame(minHeight: 36)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    @ViewBuilder private var thumbnail: some View {
        let shape = RoundedRectangle(cornerRadius: min(theme.shape.controlRadius, 14), style: .continuous)
        if let image = item.image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(shape)
                .accessibilityHidden(true)
        } else {
            Image(systemName: "text.alignleft")
                .font(.subheadline)
                .foregroundStyle(theme.colors.textMuted)
                .frame(width: 56, height: 56)
                .background(theme.colors.surfaceElevated, in: shape)
                .accessibilityHidden(true)
        }
    }
}
