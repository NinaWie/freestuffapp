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

        // Present gates over whatever rootVC is
        DispatchQueue.main.async {
            let coordinator = GateCoordinator(presentingVC: rootVC, requireTermsAfterAppUpdate: false)
            self.gateCoordinator = coordinator
            coordinator.startIfNeeded { }
        }
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

//import UIKit
//
//enum GateAlertsPresenter {
//    static func topViewController(from root: UIViewController) -> UIViewController? {
//        if let nav = root as? UINavigationController {
//            return nav.visibleViewController.flatMap { topViewController(from: $0) } ?? nav
//        }
//        if let tab = root as? UITabBarController, let selected = tab.selectedViewController {
//            return topViewController(from: selected)
//        }
//        if let presented = root.presentedViewController {
//            return topViewController(from: presented)
//        }
//        return root
//    }
//}
//
//
//final class GateAlerts {
//
//    private enum Keys {
//        static let isAdultConfirmed = "gate.isAdultConfirmed"
//        static let acceptedTermsVersion = "gate.acceptedTermsVersion"
//    }
//
//    static let termsVersion = "1"
//
//    static func startIfNeeded(from presenter: UIViewController, completion: @escaping () -> Void) {
//        // 1) Age gate
//        if !UserDefaults.standard.bool(forKey: Keys.isAdultConfirmed) {
//            presentAgeGate(from: presenter) {
//                // Continue with terms gate after confirming age
//                startIfNeeded(from: presenter, completion: completion)
//            }
//            return
//        }
//
//        // 2) Terms gate
//        let accepted = UserDefaults.standard.string(forKey: Keys.acceptedTermsVersion)
//        if accepted != termsVersion {
//            presentTermsGate(from: presenter) {
//                completion()
//            }
//            return
//        }
//
//        completion()
//    }
//
//    private static func presentAgeGate(from presenter: UIViewController, onAgree: @escaping () -> Void) {
//        let alert = UIAlertController(
//            title: "18+ Required",
//            message: "This app is intended for adults (18+). Confirm you are 18 or older to continue.",
//            preferredStyle: .alert
//        )
//
//        alert.addAction(UIAlertAction(title: "I am 18+ (Agree)", style: .default) { _ in
//            UserDefaults.standard.set(true, forKey: Keys.isAdultConfirmed)
//            onAgree()
//        })
//
//        alert.addAction(UIAlertAction(title: "Decline", style: .destructive) { _ in
//            // Recommended: keep user blocked in-app rather than force-quit.
//            presentDeclinedInfo(from: presenter, message: "You must confirm you are 18+ to use this app.")
//        })
//
//        presenter.present(alert, animated: true)
//    }
//
//    private static func presentTermsGate(from presenter: UIViewController, onAgree: @escaping () -> Void) {
//        let alert = UIAlertController(
//            title: "Terms of Use",
//            message: "To use this app, you must agree to the Terms. We have zero tolerance for objectionable content or abusive behavior.",
//            preferredStyle: .alert
//        )
//
//        alert.addAction(UIAlertAction(title: "View Terms", style: .default) { _ in
//            // Option A: show an in-app terms screen (recommended)
//            let vc = TermsViewController(text: TermsText.current)
//            let nav = UINavigationController(rootViewController: vc)
//            nav.modalPresentationStyle = .formSheet
//            presenter.present(nav, animated: true)
//            
//            // Re-present the terms gate once they close Terms:
//            vc.onClose = { [weak presenter] in
//                guard let presenter else { return }
//                presenter.dismiss(animated: true) {
//                    presentTermsGate(from: presenter, onAgree: onAgree)
//                }
//            }
//        })
//
//        alert.addAction(UIAlertAction(title: "I Agree", style: .default) { _ in
//            UserDefaults.standard.set(termsVersion, forKey: Keys.acceptedTermsVersion)
//            onAgree()
//        })
//
//        alert.addAction(UIAlertAction(title: "Decline", style: .destructive) { _ in
//            presentDeclinedInfo(from: presenter, message: "You must agree to the Terms to use this app.")
//        })
//
//        presenter.present(alert, animated: true)
//    }
//
//    private static func presentDeclinedInfo(from presenter: UIViewController, message: String) {
//        let info = UIAlertController(title: "Cannot Continue", message: message, preferredStyle: .alert)
//        info.addAction(UIAlertAction(title: "OK", style: .default))
//        presenter.present(info, animated: true)
//    }
//}
