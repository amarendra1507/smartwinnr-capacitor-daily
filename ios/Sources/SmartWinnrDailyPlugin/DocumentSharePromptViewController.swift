//
//  DocumentSharePromptViewController.swift
//  SmartwinnrCapacitorDaily
//
//  Pre-broadcast informational popup shown before iOS surfaces
//  `RPSystemBroadcastPickerView` when a document-share session begins.
//  Parity with the web `showInlineSharePromptAlert` flow, with copy and
//  illustration tailored to iOS's screen broadcast UI.
//

import UIKit

protocol DocumentSharePromptDelegate: AnyObject {
    func documentSharePromptDidConfirm()
}

final class DocumentSharePromptViewController: UIViewController {

    weak var delegate: DocumentSharePromptDelegate?

    private enum Copy {
        static let intro = "Everything on your screen, including notifications, will be recorded. Enable Do Not Disturb to prevent unexpected notifications."
        static let guidance = "Please tap \"ScreenBroadcast\" and then \"Start Broadcast\" so the avatar can follow along and your session is captured correctly."
        static let cta = "Share Screen to Continue"
        static let sheetTitle = "Screen Broadcast"
        static let mockExtensionName = "ScreenBroadcast"
        static let mockStartButton = "Start Broadcast"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        isModalInPresentation = true
        view.backgroundColor = UIColor(red: 0.12, green: 0.12, blue: 0.18, alpha: 1.0)
        setupUI()
    }

    private func setupUI() {
        let introLabel = UILabel()
        introLabel.text = Copy.intro
        introLabel.font = .systemFont(ofSize: 15, weight: .regular)
        introLabel.textColor = .white
        introLabel.textAlignment = .center
        introLabel.numberOfLines = 0

        let illustration = makeBroadcastIllustration()

        let guidanceLabel = UILabel()
        guidanceLabel.text = Copy.guidance
        guidanceLabel.font = .systemFont(ofSize: 13, weight: .regular)
        guidanceLabel.textColor = UIColor.white.withAlphaComponent(0.75)
        guidanceLabel.textAlignment = .center
        guidanceLabel.numberOfLines = 0

        let ctaButton = UIButton(type: .system)
        ctaButton.setTitle(Copy.cta, for: .normal)
        ctaButton.setTitleColor(.white, for: .normal)
        ctaButton.titleLabel?.font = .boldSystemFont(ofSize: 17)
        ctaButton.backgroundColor = .systemBlue
        ctaButton.layer.cornerRadius = 12
        ctaButton.addTarget(self, action: #selector(ctaTapped), for: .touchUpInside)
        ctaButton.translatesAutoresizingMaskIntoConstraints = false
        ctaButton.heightAnchor.constraint(equalToConstant: 50).isActive = true

        let stack = UIStackView(arrangedSubviews: [introLabel, illustration, guidanceLabel, ctaButton])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 20
        stack.setCustomSpacing(24, after: illustration)
        stack.setCustomSpacing(24, after: guidanceLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
    }

    /// Static mock of the iOS system broadcast picker sheet so users know
    /// what to expect on the next screen. Mirrors the native sheet layout:
    /// record icon + "Screen Broadcast" header, the extension row with a
    /// trailing checkmark, and a "Start Broadcast" action row.
    private func makeBroadcastIllustration() -> UIView {
        let card = UIView()
        card.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        card.layer.cornerRadius = 18
        card.layer.masksToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false

        // Header: record icon + "Screen Broadcast" label, centered.
        let recordIcon = UIImageView(image: UIImage(systemName: "record.circle"))
        recordIcon.tintColor = .white
        recordIcon.contentMode = .scaleAspectFit
        recordIcon.translatesAutoresizingMaskIntoConstraints = false
        recordIcon.widthAnchor.constraint(equalToConstant: 24).isActive = true
        recordIcon.heightAnchor.constraint(equalToConstant: 24).isActive = true

        let headerLabel = UILabel()
        headerLabel.text = Copy.sheetTitle
        headerLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        headerLabel.textColor = .white
        headerLabel.textAlignment = .center

        let headerStack = UIStackView(arrangedSubviews: [recordIcon, headerLabel])
        headerStack.axis = .vertical
        headerStack.alignment = .center
        headerStack.spacing = 6
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        let divider1 = makeDivider()
        let divider2 = makeDivider()

        // Extension row: app icon + name + trailing checkmark.
        let appIcon = UIView()
        appIcon.backgroundColor = UIColor(red: 0.40, green: 0.36, blue: 0.95, alpha: 1.0)
        appIcon.layer.cornerRadius = 6
        appIcon.translatesAutoresizingMaskIntoConstraints = false
        appIcon.widthAnchor.constraint(equalToConstant: 28).isActive = true
        appIcon.heightAnchor.constraint(equalToConstant: 28).isActive = true

        let appLetter = UILabel()
        appLetter.text = "S"
        appLetter.font = .boldSystemFont(ofSize: 16)
        appLetter.textColor = .white
        appLetter.textAlignment = .center
        appLetter.translatesAutoresizingMaskIntoConstraints = false
        appIcon.addSubview(appLetter)
        NSLayoutConstraint.activate([
            appLetter.centerXAnchor.constraint(equalTo: appIcon.centerXAnchor),
            appLetter.centerYAnchor.constraint(equalTo: appIcon.centerYAnchor)
        ])

        let extensionName = UILabel()
        extensionName.text = Copy.mockExtensionName
        extensionName.font = .systemFont(ofSize: 15, weight: .regular)
        extensionName.textColor = .white

        let checkmark = UIImageView(image: UIImage(systemName: "checkmark"))
        checkmark.tintColor = .white
        checkmark.contentMode = .scaleAspectFit
        checkmark.translatesAutoresizingMaskIntoConstraints = false
        checkmark.widthAnchor.constraint(equalToConstant: 18).isActive = true
        checkmark.heightAnchor.constraint(equalToConstant: 18).isActive = true

        let extensionRow = UIStackView(arrangedSubviews: [appIcon, extensionName, UIView(), checkmark])
        extensionRow.axis = .horizontal
        extensionRow.alignment = .center
        extensionRow.spacing = 10
        extensionRow.translatesAutoresizingMaskIntoConstraints = false

        // Start Broadcast row (centered text, acts like a button).
        let startLabel = UILabel()
        startLabel.text = Copy.mockStartButton
        startLabel.font = .systemFont(ofSize: 16, weight: .regular)
        startLabel.textColor = .white
        startLabel.textAlignment = .center
        startLabel.translatesAutoresizingMaskIntoConstraints = false

        let content = UIStackView(arrangedSubviews: [headerStack, divider1, extensionRow, divider2, startLabel])
        content.axis = .vertical
        content.alignment = .fill
        content.spacing = 12
        content.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(content)

        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])

        return card
    }

    private func makeDivider() -> UIView {
        let divider = UIView()
        divider.backgroundColor = UIColor.white.withAlphaComponent(0.25)
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        return divider
    }

    @objc private func ctaTapped() {
        dismiss(animated: true) { [weak self] in
            self?.delegate?.documentSharePromptDidConfirm()
        }
    }
}
