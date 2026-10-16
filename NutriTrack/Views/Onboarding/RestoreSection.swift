import SwiftUI
import CoreData

struct RestoreSection: View {
    @Environment(\.theme) private var theme
    @Environment(\.managedObjectContext) private var ctx
    @StateObject private var model = RestoreModel()
    let engine: SyncEngine

    var body: some View {
        Section {
            Button {
                Task { await model.run(engine: engine, in: ctx) }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.down.circle")
                        .foregroundStyle(theme.colors.accent)
                    Text("Restore my data")
                        .foregroundStyle(theme.colors.textPrimary)
                    Spacer()
                    if model.isWorking { ProgressView() }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(model.isWorking)
        } header: {
            Text("Used NutriTrack before?")
        } footer: {
            switch model.phase {
            case .idle:
                Text("Brings back your profile, meals, weigh-ins, check-ins and training from your server. Tailscale must be on.")
            case .working(let message):
                Text(message)
            case .failed(let message):
                Text(message)
                    .foregroundStyle(theme.colors.warning)
            }
        }
        .listRowBackground(theme.colors.surface)
    }
}
