import SwiftUI
import CoreData

struct SupplementsView: View {
    @Environment(\.managedObjectContext) private var ctx
    @Environment(\.theme) private var theme
    @FetchRequest(entity: SupplementTemplate.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \SupplementTemplate.name, ascending: true)])
    private var templates: FetchedResults<SupplementTemplate>

    @FetchRequest private var todayLogs: FetchedResults<SupplementLog>
    @State private var showForm = false
    @State private var editingTemplate: SupplementTemplate?
    @State private var pendingDeleteLog: SupplementLog?
    @State private var pendingDeleteTemplate: SupplementTemplate?
    @State private var loggedMessage: String?

    init() {
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        _todayLogs = FetchRequest(
            entity: SupplementLog.entity(),
            sortDescriptors: [NSSortDescriptor(keyPath: \SupplementLog.timestamp, ascending: false)],
            predicate: NSPredicate(format: "timestamp >= %@ AND timestamp < %@", start as NSDate, end as NSDate)
        )
    }

    private func displayName(for log: SupplementLog) -> String {
        log.name ?? templates.first(where: { $0.id?.uuidString == log.templateID })?.name ?? "Supplement"
    }

    private func doseStepper(for log: SupplementLog) -> some View {
        HStack(spacing: 0) {
            Button {
                log.setDoses(log.doses - 0.5, in: ctx)
            } label: {
                Image(systemName: "minus")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.colors.textSecondary)
                    .frame(width: 36, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Half a dose less")
            Text(String(format: "%g×", log.doses))
                .font(theme.number(.subheadline))
                .foregroundStyle(theme.colors.textPrimary)
                .frame(minWidth: 36)
                .accessibilityLabel(String(format: "%g doses", log.doses))
            Button {
                log.setDoses(log.doses + 0.5, in: ctx)
            } label: {
                Image(systemName: "plus")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.colors.textSecondary)
                    .frame(width: 36, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Half a dose more")
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ScreenHeader(eyebrow: "Stack", title: "Supplements") {
                    Button { showForm = true } label: {
                        Image(systemName: "plus")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.colors.onAccent)
                            .frame(width: 36, height: 36)
                            .background(theme.colors.accent, in: Circle())
                    }
                    .accessibilityLabel("Add supplement")
                }

                if !todayLogs.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        EyebrowText("Logged today")
                        ForEach(todayLogs) { log in
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(theme.colors.success)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(displayName(for: log))
                                        .font(theme.body(.subheadline))
                                        .foregroundStyle(theme.colors.textPrimary)
                                    Text(log.timestamp ?? Date(), style: .time)
                                        .font(theme.body(.caption))
                                        .foregroundStyle(theme.colors.textMuted)
                                }
                                Spacer()
                                doseStepper(for: log)
                                Button {
                                    pendingDeleteLog = log
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundStyle(theme.colors.danger)
                                        .frame(width: 44, height: 44)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Delete \(displayName(for: log)) log")
                            }
                        }
                    }
                    .themedCard()
                }

                if templates.isEmpty {
                    EmptyStateCard(
                        icon: "pills",
                        title: "No supplements yet",
                        message: "Add what you take and log it in one tap.",
                        actionTitle: "Add supplement",
                        action: { showForm = true }
                    )
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        EyebrowText("My Supplements")
                        ForEach(templates) { template in
                            HStack(spacing: 0) {
                                SupplementRowView(template: template) {
                                    SupplementLog.log(template: template, doses: 1, in: ctx)
                                    withAnimation { loggedMessage = "\(template.name ?? "Supplement") logged" }
                                }
                                Button {
                                    editingTemplate = template
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.caption)
                                        .foregroundStyle(theme.colors.textSecondary)
                                        .frame(width: 44, height: 44)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Edit \(template.name ?? "supplement")")
                                Button {
                                    pendingDeleteTemplate = template
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundStyle(theme.colors.danger)
                                        .frame(width: 44, height: 44)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Delete \(template.name ?? "supplement")")
                            }
                        }
                    }
                    .themedCard()
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(theme.colors.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .hidesCaptureButton()
        .toolbarBackground(theme.colors.background, for: .navigationBar)
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        .alert("Delete this log?",
               isPresented: Binding(get: { pendingDeleteLog != nil },
                                    set: { if !$0 { pendingDeleteLog = nil } })) {
            Button("Delete", role: .destructive) {
                if let log = pendingDeleteLog {
                    let day = log.timestamp ?? Date()
                    ctx.delete(log)
                    try? ctx.save()
                    EvaluationService.refreshClosedDay(containing: day, in: ctx)
                }
                pendingDeleteLog = nil
            }
            Button("Cancel", role: .cancel) { pendingDeleteLog = nil }
        }
        .alert("Delete this supplement?",
               isPresented: Binding(get: { pendingDeleteTemplate != nil },
                                    set: { if !$0 { pendingDeleteTemplate = nil } })) {
            Button("Delete", role: .destructive) {
                if let template = pendingDeleteTemplate { ctx.delete(template); try? ctx.save() }
                pendingDeleteTemplate = nil
            }
            Button("Cancel", role: .cancel) { pendingDeleteTemplate = nil }
        }
        .sheet(isPresented: $showForm) {
            SupplementTemplateFormView(template: nil)
        }
        .sheet(item: $editingTemplate) { t in
            SupplementTemplateFormView(template: t)
        }
        .overlay(alignment: .bottom) {
            if let msg = loggedMessage {
                let shape = RoundedRectangle(cornerRadius: theme.shape.controlRadius, style: .continuous)
                Text(msg)
                    .font(theme.body(.subheadline).weight(.medium))
                    .foregroundStyle(theme.colors.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(theme.colors.surfaceElevated, in: shape)
                    .overlay { shape.strokeBorder(theme.colors.border, lineWidth: 0.5) }
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { loggedMessage = nil }
                        }
                    }
            }
        }
    }
}
