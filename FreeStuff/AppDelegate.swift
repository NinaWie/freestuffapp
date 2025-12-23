import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    private var gateCoordinator: GateCoordinator?
    
    static var anonUserId: String = "unknown"

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        do {
            AppDelegate.anonUserId = try AnonymousUserID.getOrCreate()
        } catch {
            AppDelegate.anonUserId = UUID().uuidString.lowercased()
        }
        
//        // debugging: set terms confirmation to false
//        UserDefaults.standard.set(false, forKey: "gate.isAdultConfirmed")
//        UserDefaults.standard.set("0", forKey: "gate.acceptedTermsVersion")
        
        window = UIWindow(frame: UIScreen.main.bounds)

        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let rootVC = storyboard.instantiateInitialViewController()!

        window?.rootViewController = rootVC
        window?.makeKeyAndVisible()

        // Present gates over ViewController
        let coordinator = GateCoordinator(presentingVC: rootVC, requireTermsAfterAppUpdate: false)
        self.gateCoordinator = coordinator
        coordinator.startIfNeeded {        }
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
