import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        BackgroundModelClient.shared.activate()
        SyncEngine.shared?.start()
        return true
    }

    func application(_ application: UIApplication,
                     handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        SyncEngine.shared?.logLaunch(inBackground: true)
        switch identifier {
        case BackgroundModelClient.identifier:
            BackgroundModelClient.shared.backgroundCompletionHandler = completionHandler
            BackgroundModelClient.shared.activate()
        case SyncClient.identifier:
            guard let engine = SyncEngine.shared else {
                completionHandler()
                return
            }
            engine.client.backgroundCompletionHandler = completionHandler
            engine.client.activate()
        default:
            completionHandler()
        }
    }
}
