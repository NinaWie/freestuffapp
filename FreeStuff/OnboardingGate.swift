//
//  OnboardingGate.swift
//  FreeStuff
//
//  Created by Nina Wiedemann on 20.12.25.
//  Copyright © 2025 Nina Wiedemann. All rights reserved.
//

import UIKit

enum OnboardingGate {
    // Bump this when your Terms text changes.
    // Example: "2025-12-20"
    static let termsVersion = "1"

    private enum Keys {
        static let isAdultConfirmed = "gate.isAdultConfirmed"
        static let acceptedTermsVersion = "gate.acceptedTermsVersion"
        static let lastSeenAppVersion = "gate.lastSeenAppVersion"
    }

    static var currentAppVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    static var isAdultConfirmed: Bool {
        UserDefaults.standard.bool(forKey: Keys.isAdultConfirmed)
    }

    static func setAdultConfirmed() {
        UserDefaults.standard.set(true, forKey: Keys.isAdultConfirmed)
    }

    static var acceptedTermsVersion: String? {
        UserDefaults.standard.string(forKey: Keys.acceptedTermsVersion)
    }

    static func setAcceptedTerms() {
        UserDefaults.standard.set(termsVersion, forKey: Keys.acceptedTermsVersion)
    }

    static var lastSeenAppVersion: String? {
        UserDefaults.standard.string(forKey: Keys.lastSeenAppVersion)
    }

    static func setLastSeenAppVersion() {
        UserDefaults.standard.set(currentAppVersion, forKey: Keys.lastSeenAppVersion)
    }

    static func needsTermsAcceptance(requireAfterAppUpdate: Bool) -> Bool {
        let termsChanged = (acceptedTermsVersion != termsVersion)

        if !requireAfterAppUpdate {
            return termsChanged
        }

        let appUpdated = (lastSeenAppVersion != currentAppVersion)
        return termsChanged || appUpdated
    }
}

/// Presents gating modals before allowing access to the main UI.
final class GateCoordinator {
    private weak var presentingVC: UIViewController?

    /// Configure whether you want to require re-acceptance after each app update.
    private let requireTermsAfterAppUpdate: Bool

    init(presentingVC: UIViewController, requireTermsAfterAppUpdate: Bool = false) {
        self.presentingVC = presentingVC
        self.requireTermsAfterAppUpdate = requireTermsAfterAppUpdate
    }

    func startIfNeeded(onCompleted: @escaping () -> Void) {
        guard let presentingVC else { return }

        // Terms acceptance
        if OnboardingGate.needsTermsAcceptance(requireAfterAppUpdate: requireTermsAfterAppUpdate) {
            let vc = TermsGateViewController(termsText: TermsText.current)
            vc.onAgree = { [weak self] in
                OnboardingGate.setAcceptedTerms()
                OnboardingGate.setAdultConfirmed()
                OnboardingGate.setLastSeenAppVersion()
                self?.dismissPresented {
                    onCompleted()
                }
            }
            vc.onDecline = { [weak vc] in
                vc?.showDeclinedState()
            }

            present(vc, over: presentingVC)
            return
        }

        // All good
        OnboardingGate.setLastSeenAppVersion()
        onCompleted()
    }

    private func present(_ vc: UIViewController, over presenting: UIViewController) {
        vc.modalPresentationStyle = .fullScreen
        presenting.present(vc, animated: true)
    }

    private func dismissPresented(_ completion: @escaping () -> Void) {
        presentingVC?.presentedViewController?.dismiss(animated: true, completion: completion)
    }
}

