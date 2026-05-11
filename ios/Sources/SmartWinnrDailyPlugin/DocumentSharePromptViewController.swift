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
        static let title = "Ready to Share Your Screen"
        static let intro = "This role play uses a shareable document, so we need to record your screen to capture what you present. After you tap the button below, iOS will show the broadcast prompt."
        static let guidance = "Please tap \"SmartWinnr Screen Broadcast\" and then \"Start Broadcast\" so the avatar can follow along and your session is captured correctly."
        static let cta = "Share Screen to Continue"
        static let mockExtensionName = "SmartWinnr Screen Broadcast"
        static let mockStartButton = "Start Broadcast"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        isModalInPresentation = true
        view.backgroundColor = .systemBackground
        setupUI()
    }

    private func setupUI() {
        let titleLabel = UILabel()
        titleLabel.text = Copy.title
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        let introLabel = UILabel()
        introLabel.text = Copy.intro
        introLabel.font = .systemFont(ofSize: 15, weight: .regular)
        introLabel.textColor = .secondaryLabel
        introLabel.textAlignment = .center
        introLabel.numberOfLines = 0

        let illustration = makeBroadcastIllustration()

        let guidanceLabel = UILabel()
        guidanceLabel.text = Copy.guidance
        guidanceLabel.font = .systemFont(ofSize: 14, weight: .regular)
        guidanceLabel.textColor = .secondaryLabel
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

        let stack = UIStackView(arrangedSubviews: [titleLabel, introLabel, illustration, guidanceLabel, ctaButton])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 14
        stack.setCustomSpacing(18, after: introLabel)
        stack.setCustomSpacing(18, after: illustration)
        stack.setCustomSpacing(20, after: guidanceLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }

    /// Static mock of the iOS system broadcast picker sheet so users know
    /// what to expect on the next screen.
    private func makeBroadcastIllustration() -> UIView {
        let card = UIView()
        card.backgroundColor = UIColor.secondarySystemBackground
        card.layer.cornerRadius = 14
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor.separator.cgColor
        card.translatesAutoresizingMaskIntoConstraints = false
        card.heightAnchor.constraint(equalToConstant: 130).isActive = true

        let iconBackground = UIView()
        iconBackground.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.15)
        iconBackground.layer.cornerRadius = 10
        iconBackground.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: "record.circle"))
        icon.tintColor = .systemRed
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconBackground.addSubview(icon)

        let nameLabel = UILabel()
        nameLabel.text = Copy.mockExtensionName
        nameLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        nameLabel.textColor = .label

        let radio = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        radio.tintColor = .systemBlue
        radio.translatesAutoresizingMaskIntoConstraints = false
        radio.widthAnchor.constraint(equalToConstant: 20).isActive = true
        radio.heightAnchor.constraint(equalToConstant: 20).isActive = true

        let row = UIStackView(arrangedSubviews: [iconBackground, nameLabel, radio])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false

        let startBtn = UILabel()
        startBtn.text = Copy.mockStartButton
        startBtn.font = .boldSystemFont(ofSize: 14)
        startBtn.textColor = .white
        startBtn.textAlignment = .center
        startBtn.backgroundColor = .systemBlue
        startBtn.layer.cornerRadius = 8
        startBtn.layer.masksToBounds = true
        startBtn.translatesAutoresizingMaskIntoConstraints = false
        startBtn.heightAnchor.constraint(equalToConstant: 32).isActive = true

        let pointer = UILabel()
        pointer.text = "👆"
        pointer.font = .systemFont(ofSize: 18)
        pointer.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(row)
        card.addSubview(startBtn)
        card.addSubview(pointer)

        NSLayoutConstraint.activate([
            iconBackground.widthAnchor.constraint(equalToConstant: 32),
            iconBackground.heightAnchor.constraint(equalToConstant: 32),
            icon.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20),

            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),

            startBtn.topAnchor.constraint(equalTo: row.bottomAnchor, constant: 16),
            startBtn.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 60),
            startBtn.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -60),

            pointer.leadingAnchor.constraint(equalTo: startBtn.trailingAnchor, constant: -10),
            pointer.centerYAnchor.constraint(equalTo: startBtn.bottomAnchor, constant: 4)
        ])

        return card
    }

    @objc private func ctaTapped() {
        dismiss(animated: true) { [weak self] in
            self?.delegate?.documentSharePromptDidConfirm()
        }
    }
}
