import SwiftUI

struct GoalStepView: View {
    @Environment(\.theme) private var theme
    @Binding var goal: Goal
    let onComplete: () -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(Goal.offered) { g in
                    Button {
                        goal = g
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(g.choiceName)
                                    .font(theme.display(.headline))
                                    .foregroundStyle(theme.colors.textPrimary)
                                Text(g.choiceDescription)
                                    .font(theme.body(.caption))
                                    .foregroundStyle(theme.colors.textSecondary)
                            }
                            Spacer()
                            Image(systemName: goal == g ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(goal == g ? theme.colors.accent : theme.colors.textMuted)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(goal == g ? .isSelected : [])
                }
                .listRowBackground(theme.colors.surface)
            }
            .scrollContentBackground(.hidden)
            .background(theme.colors.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                Button("Continue", action: onComplete)
                    .buttonStyle(.themedPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(theme.colors.background)
            }
            .navigationTitle("Your goal")
        }
    }
}
