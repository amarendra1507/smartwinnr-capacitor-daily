//
//  DocumentSharePromptViewController.swift
//  SmartwinnrCapacitorDaily
//
//  Pre-broadcast informational popup shown before iOS surfaces
//  `RPSystemBroadcastPickerView` when a document-share session begins.
//  Parity with the web `showInlineSharePromptAlert` flow, presented as a
//  centered LIGHT popup card over a dimmed backdrop.
//
//  Design goals — idiot-proof, zero ambiguity:
//    - ONE obviously-tappable action: the gradient CTA pulses + glows so
//      there's no doubt which button starts the flow.
//    - The "Not now" option is a quiet plain-text secondary so it can't be
//      mistaken for the primary action.
//    - A compact, numbered STEP-BY-STEP guide previews the two things the
//      user must do on Apple's next screen (1 pick SmartWinnr, 2 tap Start
//      Broadcast). The little preview chips are small and clearly illustrative
//      so they don't compete with the real CTA.
//    - Explains WHY sharing is needed (the recording already runs from join —
//      this only shares the screen so what they present is captured).
//
//  Supports two modes:
//    - .initial  first-time request
//    - .retry    shown by the recovery flow if the broadcast never started
//                (e.g. the user cancelled Apple's picker)
//
//  (Copy is hardcoded English for now; it will be made translatable later.)
//

import UIKit

protocol DocumentSharePromptDelegate: AnyObject {
    func documentSharePromptDidConfirm()
    func documentSharePromptDidCancel()
}

/// A UIView whose backing layer is a gradient — auto-resizes with Auto Layout
/// (no manual frame juggling), used for the icon badge and the steps card.
final class GradientBackedView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }
    var gradientLayer: CAGradientLayer { layer as! CAGradientLayer }
}

/// A gradient-filled button. The gradient is a sublayer kept in sync with the
/// button's bounds/cornerRadius so titles and touch handling stay intact.
final class GradientButton: UIButton {
    private let gradient = CAGradientLayer()

    var gradientColors: [CGColor] = [] {
        didSet { gradient.colors = gradientColors }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        layer.insertSublayer(gradient, at: 0)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
        gradient.cornerRadius = layer.cornerRadius
    }
}

final class DocumentSharePromptViewController: UIViewController {

    enum Mode {
        case initial
        case retry
    }

    weak var delegate: DocumentSharePromptDelegate?
    var mode: Mode = .initial

    private weak var ctaButton: GradientButton?
    // Kept so viewDidLayoutSubviews can pin their preferredMaxLayoutWidth to the
    // real laid-out width — otherwise a multiline label inside the scroll view
    // can size its height at the wrong width and clip the last line.
    private weak var promptTitleLabel: UILabel?
    private weak var promptIntroLabel: UILabel?

    // Light palette + a modern indigo→violet gradient for accents.
    private enum Palette {
        static let backdrop = UIColor.black.withAlphaComponent(0.45)
        static let accent = UIColor(red: 0.0, green: 0.0, blue: 0.788, alpha: 1.0) // brand blue #0000C9
        static let gradientStart = UIColor(red: 0.0, green: 0.0, blue: 0.788, alpha: 1.0) // #0000C9
        static let gradientEnd = UIColor(red: 0.20, green: 0.20, blue: 0.90, alpha: 1.0) // brighter tint for depth
        static let card = UIColor.white
        static let stepTint = UIColor(red: 0.95, green: 0.95, blue: 1.0, alpha: 1.0)
        static let textPrimary = UIColor(red: 0.12, green: 0.14, blue: 0.22, alpha: 1.0)
        static let textSecondary = UIColor(red: 0.36, green: 0.40, blue: 0.48, alpha: 1.0)
        static let textTertiary = UIColor(red: 0.55, green: 0.58, blue: 0.65, alpha: 1.0)
        static let hairline = UIColor(red: 0.85, green: 0.86, blue: 0.90, alpha: 1.0)
    }

    // Copy shared across both modes. NOTE: the session recording runs
    // automatically from the moment the user joins — this step is only about
    // SHARING the screen so what the user presents is captured with the session.
    // Copy must not imply that recording starts here.
    private enum Copy {
        static let stepsCaption = "ON THE NEXT SCREEN, JUST:"
        static let step1 = "Make sure \u{201C}ScreenBroadcast\u{201D} is ticked"
        static let step2 = "Tap \u{201C}Start Sharing\u{201D}"
        // After the broadcast starts iOS shows a red recording indicator at the
        // top (and the timer starts) — it never says "sharing started". Apple's
        // sharing box can linger, so tapping the dimmed area outside it dismisses
        // it and returns the user to the role play.
        static let step3 = "Once you see the red recording dot at the top of the screen, tap the greyed-out area outside the box to close it and return to your role play"
        static let guidance = "Your whole screen is shared, so turn on Do Not Disturb to avoid interruptions."
        static let privacy = "Your screen is shared only during this role play and stops when you end the session."
        static let notNow = "Not now"
        static let mockStartButton = "Start Sharing"
    }

    // Mode-dependent copy.
    private var titleText: String {
        mode == .retry ? "Let\u{2019}s try that again" : "Ready to Share Your Screen"
    }
    private var introText: String {
        mode == .retry
            ? "Screen sharing didn\u{2019}t start, so what you present isn\u{2019}t being shared yet. This role play needs your screen shared so the avatar can follow along."
            : "This role play uses a shareable document, so please share your screen. That way the avatar can follow what you present and your session is captured correctly."
    }
    private var ctaText: String {
        mode == .retry ? "Try again" : "Share Screen to Continue"
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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Pin each multiline label's wrap width to its actual width so it reports
        // the correct (taller) intrinsic height and never clips its last line.
        // Guarded so it only relayouts when the width actually changed (no loop).
        var needsRelayout = false
        for label in [promptTitleLabel, promptIntroLabel].compactMap({ $0 }) {
            let width = label.bounds.width
            if width > 0 && abs(label.preferredMaxLayoutWidth - width) > 0.5 {
                label.preferredMaxLayoutWidth = width
                needsRelayout = true
            }
        }
        if needsRelayout {
            view.layoutIfNeeded()
        }
    }
    

    /// Gentle, infinite scale pulse on the CTA so the user's eye is drawn to the
    /// one button they should tap — the single clearest signal that this (and
    /// not the small preview pill or "Not now") is the action.
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
        // Shadow wrapper (can't clip) + rounded card (clips content).
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
        titleLabel.text = titleText
        titleLabel.font = .systemFont(ofSize: 21, weight: .bold)
        titleLabel.textColor = Palette.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        let introLabel = UILabel()
        introLabel.text = introText
        introLabel.font = .systemFont(ofSize: 15, weight: .regular)
        introLabel.textColor = Palette.textSecondary
        introLabel.textAlignment = .center
        introLabel.numberOfLines = 0
        introLabel.lineBreakMode = .byWordWrapping
        // Never truncate the intro — it must wrap to its full height (the scroll
        // view absorbs any overflow on short screens).
        introLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        self.promptTitleLabel = titleLabel
        self.promptIntroLabel = introLabel

        let stepsGuide = makeStepsGuide()

        let guidanceLabel = UILabel()
        guidanceLabel.text = Copy.guidance
        guidanceLabel.font = .systemFont(ofSize: 12, weight: .regular)
        guidanceLabel.textColor = Palette.textTertiary
        guidanceLabel.textAlignment = .center
        guidanceLabel.numberOfLines = 0

        let privacyRow = makePrivacyRow()

        // The ONE unmistakable action: gradient fill + soft glow + pulse.
        let cta = GradientButton(type: .system)
        cta.gradientColors = [Palette.gradientStart.cgColor, Palette.gradientEnd.cgColor]
        cta.setTitle(ctaText, for: .normal)
        cta.setTitleColor(.white, for: .normal)
        cta.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        cta.layer.cornerRadius = 15
        cta.layer.shadowColor = Palette.accent.cgColor
        cta.layer.shadowOpacity = 0.45
        cta.layer.shadowRadius = 14
        cta.layer.shadowOffset = CGSize(width: 0, height: 6)
        cta.addTarget(self, action: #selector(ctaTapped), for: .touchUpInside)
        cta.translatesAutoresizingMaskIntoConstraints = false
        cta.heightAnchor.constraint(equalToConstant: 54).isActive = true
        self.ctaButton = cta

        // Quiet secondary — plain text, no fill, clearly not the main action.
        let notNowButton = UIButton(type: .system)
        notNowButton.setTitle(Copy.notNow, for: .normal)
        notNowButton.setTitleColor(Palette.textTertiary, for: .normal)
        notNowButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        notNowButton.addTarget(self, action: #selector(notNowTapped), for: .touchUpInside)
        notNowButton.translatesAutoresizingMaskIntoConstraints = false
        notNowButton.heightAnchor.constraint(equalToConstant: 36).isActive = true

        let stack = UIStackView(arrangedSubviews: [badge, titleLabel, introLabel, stepsGuide, guidanceLabel, privacyRow, cta, notNowButton])
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

        // Prefer 400pt wide, shrink to 20pt margins on narrow screens; cap height
        // at 90% of the safe area and scroll internally beyond that.
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

    /// Rounded gradient icon badge at the top for a modern, designed feel.
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

    /// Short privacy-reassurance row: lock icon + one honest sentence about what
    /// is shared and for how long.
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

    // MARK: - Step-by-step guide

    /// Compact, numbered preview of what the user must do on Apple's next
    /// screen. Small illustrative chips (NOT full-size buttons) sit beside each
    /// step so they read as "here's what it'll look like", never as the action
    /// to tap right now.
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
        let step3 = makeStepRow(number: 3, text: Copy.step3, accessory: makeTapHintChip())

        let content = UIStackView(arrangedSubviews: [caption, step1, step2, step3])
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

    private func makeStepRow(number: Int, text: String, accessory: UIView? = nil) -> UIView {
        let badge = makeStepNumber(number)

        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = Palette.textPrimary
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        // Never clip the instruction vertically — it must wrap to as many lines
        // as needed rather than truncate.
        label.setContentCompressionResistancePriority(.required, for: .vertical)

        var arranged: [UIView] = [badge, label]
        if let accessory = accessory {
            accessory.setContentHuggingPriority(.required, for: .horizontal)
            accessory.setContentCompressionResistancePriority(.required, for: .horizontal)
            arranged.append(accessory)
        }

        let row = UIStackView(arrangedSubviews: arranged)
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false
        return row
    }

    /// Step 3 illustrative chip: a small "tap outside" hint icon.
    private func makeTapHintChip() -> UIView {
        let icon = UIImageView(image: UIImage(systemName: "hand.tap.fill"))
        icon.tintColor = Palette.accent
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 20).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 20).isActive = true
        return icon
    }

    /// Small gradient number badge (1, 2, …).
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

    /// Resolves the host app's icon (the same glyph iOS shows next to
    /// "ScreenBroadcast" in the picker) via the bundle's icon manifest.
    private func appIconImage() -> UIImage? {
        guard let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
              let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let files = primary["CFBundleIconFiles"] as? [String],
              let lastName = files.last else { return nil }
        return UIImage(named: lastName)
    }

    /// Step 1 illustrative chip: the real app icon (matching what shows next to
    /// "ScreenBroadcast" in the picker) + checkmark = "it's selected".
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
            // Fallback: a drawn blue tile with "S", close to the real glyph.
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

    /// Step 2 illustrative chip: a SMALL gradient "Start Broadcast" pill —
    /// mirrors the button the user will tap, but small and inside the step so
    /// it never competes with the real CTA below.
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

    @objc private func ctaTapped() {
        dismiss(animated: true) { [weak self] in
            self?.delegate?.documentSharePromptDidConfirm()
        }
    }

    @objc private func notNowTapped() {
        dismiss(animated: true) { [weak self] in
            self?.delegate?.documentSharePromptDidCancel()
        }
    }
}
