import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Any other setup you need
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Pause ongoing tasks or disable timers.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        if UserDefaults.standard.bool(forKey: "switchState") {
            locationManager.startMonitoringSignificantLocationChanges()
            locationManager.allowsBackgroundLocationUpdates = true
        }
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Undo background changes.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any paused tasks.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Save data if needed.
    }
}
