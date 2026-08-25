//
//  ScreenShareModalViewController.swift
//  SmartwinnrCapacitorDaily
//
//  Manual "Screen Share" confirmation shown when the user taps the in-call
//  screen-share control. Redesigned to match `DocumentSharePromptViewController`
//  — a centered LIGHT popup over a dimmed backdrop (not the old page sheet),
//  with the brand-blue gradient, a pulsing single CTA, and the same numbered
//  step-by-step preview of Apple's next screen so there's zero ambiguity.
//
//  Reuses `GradientBackedView` / `GradientButton` from
//  DocumentSharePromptViewController.swift (same module/target).
//

import UIKit

// MARK: - Screen Share Modal Delegate Protocol

protocol ScreenShareModalDelegate: AnyObject {
    func screenShareModalDidSelectStart()
    func screenShareModalDidCancel()
}

// MARK: - Screen Share Modal View Controller

class ScreenShareModalViewController: UIViewController {
    weak var delegate: ScreenShareModalDelegate?

    private weak var ctaButton: GradientButton?

    // Light palette + brand-blue (#0000C9) gradient, matching the doc-share popup.
    private enum Palette {
        static let backdrop = UIColor.black.withAlphaComponent(0.45)
        static let accent = UIColor(red: 0.0, green: 0.0, blue: 0.788, alpha: 1.0) // #0000C9
        static let gradientStart = UIColor(red: 0.0, green: 0.0, blue: 0.788, alpha: 1.0) // #0000C9
        static let gradientEnd = UIColor(red: 0.20, green: 0.20, blue: 0.90, alpha: 1.0)
        static let card = UIColor.white
        static let stepTint = UIColor(red: 0.95, green: 0.95, blue: 1.0, alpha: 1.0)
        static let textPrimary = UIColor(red: 0.12, green: 0.14, blue: 0.22, alpha: 1.0)
        static let textSecondary = UIColor(red: 0.36, green: 0.40, blue: 0.48, alpha: 1.0)
        static let textTertiary = UIColor(red: 0.55, green: 0.58, blue: 0.65, alpha: 1.0)
        static let hairline = UIColor(red: 0.85, green: 0.86, blue: 0.90, alpha: 1.0)
    }

    private enum Copy {
        static let title = "Share Your Screen"
        static let intro = "Show what's on your screen to everyone in the call. On the next screen, iOS just asks you to confirm."
        static let stepsCaption = "ON THE NEXT SCREEN, JUST:"
        static let step1 = "Make sure \u{201C}ScreenBroadcast\u{201D} is ticked"
        static let step2 = "Tap \u{201C}Start Sharing\u{201D}"
        static let guidance = "Your whole screen is shared, so turn on Do Not Disturb to avoid interruptions."
        static let privacy = "Sharing stops the moment you tap Stop Screen Share."
        static let cta = "Share Screen"
        static let cancel = "Cancel"
        static let mockStartButton = "Start Sharing"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        isModalInPresentation = true
        view.backgroundColor = Palette.backdrop
        setupUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startCtaPulse()
    }

    private func startCtaPulse() {
        guard let cta = ctaButton else { return }
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1.0
        pulse.toValue = 1.035
        pulse.duration = 0.9
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        cta.layer.add(pulse, forKey: "ctaPulse")
    }

    private func setupUI() {
        let shadowView = UIView()
        shadowView.backgroundColor = .clear
        shadowView.layer.shadowColor = UIColor.black.cgColor
        shadowView.layer.shadowOpacity = 0.25
        shadowView.layer.shadowRadius = 24
        shadowView.layer.shadowOffset = CGSize(width: 0, height: 8)
        shadowView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(shadowView)

        let card = UIView()
        card.backgroundColor = Palette.card
        card.layer.cornerRadius = 24
        card.layer.masksToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        shadowView.addSubview(card)

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.showsVerticalScrollIndicator = false
        card.addSubview(scroll)

        let badge = makeIconBadge()

        let titleLabel = UILabel()
        titleLabel.text = Copy.title
        titleLabel.font = .systemFont(ofSize: 21, weight: .bold)
        titleLabel.textColor = Palette.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        let introLabel = UILabel()
        introLabel.text = Copy.intro
        introLabel.font = .systemFont(ofSize: 15, weight: .regular)
        introLabel.textColor = Palette.textSecondary
        introLabel.textAlignment = .center
        introLabel.numberOfLines = 0

        let stepsGuide = makeStepsGuide()

        let guidanceLabel = UILabel()
        guidanceLabel.text = Copy.guidance
        guidanceLabel.font = .systemFont(ofSize: 12, weight: .regular)
        guidanceLabel.textColor = Palette.textTertiary
        guidanceLabel.textAlignment = .center
        guidanceLabel.numberOfLines = 0

        let privacyRow = makePrivacyRow()

        let cta = GradientButton(type: .system)
        cta.gradientColors = [Palette.gradientStart.cgColor, Palette.gradientEnd.cgColor]
        cta.setTitle(Copy.cta, for: .normal)
        cta.setTitleColor(.white, for: .normal)
        cta.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        cta.layer.cornerRadius = 15
        cta.layer.shadowColor = Palette.accent.cgColor
        cta.layer.shadowOpacity = 0.45
        cta.layer.shadowRadius = 14
        cta.layer.shadowOffset = CGSize(width: 0, height: 6)
        cta.addTarget(self, action: #selector(startButtonTapped), for: .touchUpInside)
        cta.translatesAutoresizingMaskIntoConstraints = false
        cta.heightAnchor.constraint(equalToConstant: 54).isActive = true
        self.ctaButton = cta

        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle(Copy.cancel, for: .normal)
        cancelButton.setTitleColor(Palette.textTertiary, for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.heightAnchor.constraint(equalToConstant: 36).isActive = true

        let stack = UIStackView(arrangedSubviews: [badge, titleLabel, introLabel, stepsGuide, guidanceLabel, privacyRow, cta, cancelButton])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 16
        stack.setCustomSpacing(16, after: badge)
        stack.setCustomSpacing(10, after: titleLabel)
        stack.setCustomSpacing(20, after: introLabel)
        stack.setCustomSpacing(12, after: stepsGuide)
        stack.setCustomSpacing(16, after: guidanceLabel)
        stack.setCustomSpacing(22, after: privacyRow)
        stack.setCustomSpacing(6, after: cta)
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        let preferredWidth = shadowView.widthAnchor.constraint(equalToConstant: 400)
        preferredWidth.priority = .defaultHigh
        let hugHeight = scroll.heightAnchor.constraint(equalTo: scroll.contentLayoutGuide.heightAnchor)
        hugHeight.priority = .defaultHigh

        NSLayoutConstraint.activate([
            shadowView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shadowView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            shadowView.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            shadowView.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            shadowView.heightAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.heightAnchor, multiplier: 0.9),
            preferredWidth,

            card.topAnchor.constraint(equalTo: shadowView.topAnchor),
            card.bottomAnchor.constraint(equalTo: shadowView.bottomAnchor),
            card.leadingAnchor.constraint(equalTo: shadowView.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: shadowView.trailingAnchor),

            scroll.topAnchor.constraint(equalTo: card.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            hugHeight,

            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 28),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -24)
        ])
    }

    // MARK: - Building blocks

    private func makeIconBadge() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let badge = GradientBackedView()
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.gradientLayer.colors = [Palette.gradientStart.cgColor, Palette.gradientEnd.cgColor]
        badge.gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        badge.gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        badge.layer.cornerRadius = 18
        badge.layer.masksToBounds = true
        badge.widthAnchor.constraint(equalToConstant: 60).isActive = true
        badge.heightAnchor.constraint(equalToConstant: 60).isActive = true

        let icon = UIImageView(image: UIImage(systemName: "airplayvideo"))
        icon.tintColor = .white
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 30).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 30).isActive = true
        badge.addSubview(icon)
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: badge.centerYAnchor)
        ])

        container.addSubview(badge)
        NSLayoutConstraint.activate([
            badge.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            badge.topAnchor.constraint(equalTo: container.topAnchor),
            badge.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }

    private func makePrivacyRow() -> UIView {
        let lock = UIImageView(image: UIImage(systemName: "lock.fill"))
        lock.tintColor = Palette.textTertiary
        lock.contentMode = .scaleAspectFit
        lock.translatesAutoresizingMaskIntoConstraints = false
        lock.widthAnchor.constraint(equalToConstant: 14).isActive = true
        lock.heightAnchor.constraint(equalToConstant: 14).isActive = true
        lock.setContentHuggingPriority(.required, for: .horizontal)

        let label = UILabel()
        label.text = Copy.privacy
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = Palette.textTertiary
        label.numberOfLines = 0

        let row = UIStackView(arrangedSubviews: [lock, label])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        return row
    }

    private func makeStepsGuide() -> UIView {
        let card = GradientBackedView()
        card.gradientLayer.colors = [UIColor.white.cgColor, Palette.stepTint.cgColor]
        card.gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        card.gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        card.layer.cornerRadius = 16
        card.layer.borderWidth = 1
        card.layer.borderColor = Palette.hairline.cgColor
        card.layer.masksToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false

        let caption = UILabel()
        caption.attributedText = NSAttributedString(
            string: Copy.stepsCaption,
            attributes: [.kern: 0.8]
        )
        caption.font = .systemFont(ofSize: 11, weight: .bold)
        caption.textColor = Palette.textTertiary

        let step1 = makeStepRow(number: 1, text: Copy.step1, accessory: makeExtensionChip())
        let step2 = makeStepRow(number: 2, text: Copy.step2, accessory: makeStartPill())

        let content = UIStackView(arrangedSubviews: [caption, step1, step2])
        content.axis = .vertical
        content.alignment = .fill
        content.spacing = 12
        content.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(content)

        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
        ])

        return card
    }

    private func makeStepRow(number: Int, text: String, accessory: UIView) -> UIView {
        let badge = makeStepNumber(number)

        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = Palette.textPrimary
        label.numberOfLines = 0
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        accessory.setContentHuggingPriority(.required, for: .horizontal)
        accessory.setContentCompressionResistancePriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [badge, label, accessory])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false
        return row
    }

    private func makeStepNumber(_ number: Int) -> UIView {
        let badge = GradientBackedView()
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.gradientLayer.colors = [Palette.gradientStart.cgColor, Palette.gradientEnd.cgColor]
        badge.gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        badge.gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        badge.layer.cornerRadius = 12
        badge.layer.masksToBounds = true
        badge.widthAnchor.constraint(equalToConstant: 24).isActive = true
        badge.heightAnchor.constraint(equalToConstant: 24).isActive = true
        badge.setContentHuggingPriority(.required, for: .horizontal)

        let label = UILabel()
        label.text = "\(number)"
        label.font = .systemFont(ofSize: 13, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: badge.centerYAnchor)
        ])
        return badge
    }

    private func appIconImage() -> UIImage? {
        guard let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
              let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let files = primary["CFBundleIconFiles"] as? [String],
              let lastName = files.last else { return nil }
        return UIImage(named: lastName)
    }

    private func makeExtensionChip() -> UIView {
        let appIcon: UIView
        if let icon = appIconImage() {
            let iv = UIImageView(image: icon)
            iv.contentMode = .scaleAspectFill
            iv.translatesAutoresizingMaskIntoConstraints = false
            iv.layer.cornerRadius = 5
            iv.layer.masksToBounds = true
            appIcon = iv
        } else {
            let tile = GradientBackedView()
            tile.translatesAutoresizingMaskIntoConstraints = false
            tile.gradientLayer.colors = [Palette.gradientStart.cgColor, Palette.gradientEnd.cgColor]
            tile.gradientLayer.startPoint = CGPoint(x: 0, y: 0)
            tile.gradientLayer.endPoint = CGPoint(x: 1, y: 1)
            tile.layer.cornerRadius = 5
            tile.layer.masksToBounds = true

            let letter = UILabel()
            letter.text = "S"
            letter.font = .boldSystemFont(ofSize: 13)
            letter.textColor = .white
            letter.textAlignment = .center
            letter.translatesAutoresizingMaskIntoConstraints = false
            tile.addSubview(letter)
            NSLayoutConstraint.activate([
                letter.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
                letter.centerYAnchor.constraint(equalTo: tile.centerYAnchor)
            ])
            appIcon = tile
        }
        appIcon.widthAnchor.constraint(equalToConstant: 22).isActive = true
        appIcon.heightAnchor.constraint(equalToConstant: 22).isActive = true

        let check = UIImageView(image: UIImage(systemName: "checkmark"))
        check.tintColor = Palette.accent
        check.contentMode = .scaleAspectFit
        check.translatesAutoresizingMaskIntoConstraints = false
        check.widthAnchor.constraint(equalToConstant: 14).isActive = true
        check.heightAnchor.constraint(equalToConstant: 14).isActive = true

        let chip = UIStackView(arrangedSubviews: [appIcon, check])
        chip.axis = .horizontal
        chip.alignment = .center
        chip.spacing = 6
        chip.translatesAutoresizingMaskIntoConstraints = false
        return chip
    }

    private func makeStartPill() -> UIView {
        let pill = GradientBackedView()
        pill.translatesAutoresizingMaskIntoConstraints = false
        pill.gradientLayer.colors = [Palette.gradientStart.cgColor, Palette.gradientEnd.cgColor]
        pill.gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        pill.gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        pill.layer.cornerRadius = 10
        pill.layer.masksToBounds = true

        let label = UILabel()
        label.text = Copy.mockStartButton
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: pill.topAnchor, constant: 5),
            label.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -5),
            label.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -10)
        ])
        return pill
    }

    // MARK: - Actions

    @objc private func startButtonTapped() {
        dismiss(animated: true) { [weak self] in
            self?.delegate?.screenShareModalDidSelectStart()
        }
    }

    @objc private func cancelButtonTapped() {
        dismiss(animated: true) { [weak self] in
            self?.delegate?.screenShareModalDidCancel()
        }
    }
}
