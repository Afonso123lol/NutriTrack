import SwiftUI
import CoreData

@main
struct NutriTrackApp: App {
    let persistence = Persistence.shared
    @StateObject private var pendingStore = PendingMealStore.shared
    @AppStorage("themeID") private var themeID = Theme.alpine.id
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    private var theme: Theme { Theme.preset(id: themeID) }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistence.container.viewContext)
                .environmentObject(pendingStore)
                .environment(\.theme, theme)
                .preferredColorScheme(theme.colorScheme)
                .tint(theme.colors.accent)
                .animation(.easeInOut(duration: 0.3), value: theme.id)
                .onChange(of: scenePhase, initial: true) { _, phase in
                    if phase == .active {
                        BackgroundModelClient.shared.resumeOrphanedJobs()
                        SyncEngine.shared?.logLaunch(inBackground: false)
                        EvaluationService.autoCloseMissedDays(in: persistence.container.viewContext)
                        TargetService.refreshForCurrentProfile(in: persistence.container.viewContext)
                    }
                    if phase == .background { SyncEngine.shared?.client.sendNow() }
                }
                .task {
                    guard !UserDefaults.standard.bool(forKey: "thumbnailBackfillDone") else { return }
                    await FoodEntry.backfillThumbnails(in: persistence.container.viewContext)
                    UserDefaults.standard.set(true, forKey: "thumbnailBackfillDone")
                }
        }
    }
}
