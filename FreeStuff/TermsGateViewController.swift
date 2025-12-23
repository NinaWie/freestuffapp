//
//  TermsGateViewController.swift
//  FreeStuff
//
//  Created by Nina Wiedemann on 20.12.25.
//  Copyright © 2025 Nina Wiedemann. All rights reserved.
//

import UIKit

@available(iOS 13.0, *)
final class TermsGateViewController: UIViewController {
    var onAgree: (() -> Void)?
    var onDecline: (() -> Void)?

    private let termsText: String

    private let titleLabel = UILabel()
    private let infoLabel = UILabel()
    private let textView = UITextView()
    private let ageLabel = UILabel()
    private let agreeButton = UIButton(type: .system)
    private let declineButton = UIButton(type: .system)

    init(termsText: String) {
        self.termsText = termsText
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        titleLabel.text = "Terms of Use"
        titleLabel.font = .preferredFont(forTextStyle: .title1)
        titleLabel.numberOfLines = 0
        
        ageLabel.text = "18+ Required"
        ageLabel.font = .preferredFont(forTextStyle: .headline)
        ageLabel.numberOfLines = 0

        infoLabel.text = "By continuing, you confirm you are 18 or older and agree to the Terms. We have zero tolerance for objectionable content or abusive behavior."
//        infoLabel.text = "To use this app, you must agree to the Terms. We have zero tolerance for objectionable content or abusive behavior."
        infoLabel.font = .preferredFont(forTextStyle: .body)
        infoLabel.numberOfLines = 0

        textView.text = termsText
        textView.isEditable = false
        textView.font = .preferredFont(forTextStyle: .footnote)
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.separator.cgColor
        textView.layer.cornerRadius = 8
        textView.translatesAutoresizingMaskIntoConstraints = false

        agreeButton.setTitle("I Agree & Continue", for: .normal)
        agreeButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        agreeButton.addTarget(self, action: #selector(didTapAgree), for: .touchUpInside)

        declineButton.setTitle("Exit", for: .normal)
        declineButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        declineButton.addTarget(self, action: #selector(didTapDecline), for: .touchUpInside)

        let buttonStack = UIStackView(arrangedSubviews: [agreeButton, declineButton])
        buttonStack.axis = .vertical
        buttonStack.spacing = 12

        let stack = UIStackView(arrangedSubviews: [titleLabel, ageLabel, infoLabel, textView, buttonStack])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),

            textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 220)
        ])
    }

    @objc private func didTapAgree() {
        onAgree?()
    }

    @objc private func didTapDecline() {
        onDecline?()
    }

    func showDeclinedState() {
        let alert = UIAlertController(
            title: "Cannot Continue",
            message: "You must agree to the Terms to use this app.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
