//
//  CallSettingsViewController.swift
//  SmartwinnrCapacitorDaily
//

import UIKit
import Daily
import AVFoundation

class CallSettingsViewController: UIViewController {

    private let callClient: CallClient
    private var lastNetworkQuality: String
    private let isAudioModeOnly: Bool

    private let textColor = UIColor(red: 34.0/255.0, green: 34.0/255.0, blue: 34.0/255.0, alpha: 1.0)
    private let brandColor = UIColor(red: 0, green: 0, blue: 201.0/255.0, alpha: 1.0)
    private let pageBg = UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1.0)

    private var connectivityLabel: UILabel?
    private var connectivityDot: UIView?
    private var qualityLabel: UILabel?
    private var qualityDot: UIView?
    private var lastCheckedLabel: UILabel?
    private var refreshButton: UIButton?
    private var networkCheckTime: Date = Date()
    private var countdownTimer: Timer?

    init(callClient: CallClient, networkQuality: String, isAudioModeOnly: Bool) {
        self.callClient = callClient
        self.lastNetworkQuality = networkQuality
        self.isAudioModeOnly = isAudioModeOnly
        super.init(nibName: nil, bundle: nil)
        print("[NetworkDebug] CallSettingsVC init — networkQuality: '\(networkQuality)', callState: \(callClient.callState), hasNetworkStats: \(callClient.networkStatistics != nil)")
        modalPresentationStyle = .pageSheet
        if #available(iOS 15.0, *) {
            if let sheet = sheetPresentationController {
                sheet.detents = [.medium(), .large()]
            }
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = pageBg
        setupUI()
        refreshNetworkStats()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    // MARK: - UI Setup

    private func setupUI() {
        // Header
        let headerView = UIView()
        headerView.backgroundColor = brandColor
        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)

        let titleLabel = UILabel()
        titleLabel.text = "Call Settings"
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(titleLabel)

        let closeButton = UIButton()
        let closeConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        closeButton.setImage(UIImage(systemName: "xmark", withConfiguration: closeConfig), for: .normal)
        closeButton.tintColor = .white
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        headerView.addSubview(closeButton)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 52),

            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            closeButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 36),
            closeButton.heightAnchor.constraint(equalToConstant: 36),
        ])

        // Scroll content
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])

        // NETWORK card
        let networkCard = createCard()
        contentView.addSubview(networkCard)

        let networkHeader = createSectionHeader(icon: "globe", title: "NETWORK")
        networkCard.addSubview(networkHeader)

        // Refresh button
        let refresh = UIButton()
        let refreshConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        refresh.setImage(UIImage(systemName: "arrow.clockwise", withConfiguration: refreshConfig), for: .normal)
        refresh.tintColor = brandColor
        refresh.translatesAutoresizingMaskIntoConstraints = false
        refresh.addTarget(self, action: #selector(refreshTapped), for: .touchUpInside)
        networkCard.addSubview(refresh)
        self.refreshButton = refresh

        // Connectivity pill
        let connectivityPill = createStatPill(label: "Connectivity", value: "Connected", color: .systemGreen)
        self.connectivityLabel = connectivityPill.viewWithTag(1001) as? UILabel
        self.connectivityDot = connectivityPill.viewWithTag(1002)

        // Quality pill
        let qualityPill = createStatPill(label: "Quality", value: qualityText(lastNetworkQuality), color: qualityColor(lastNetworkQuality))
        self.qualityLabel = qualityPill.viewWithTag(1001) as? UILabel
        self.qualityDot = qualityPill.viewWithTag(1002)

        // Pill row
        let pillRow = UIStackView(arrangedSubviews: [connectivityPill, qualityPill])
        pillRow.axis = .horizontal
        pillRow.spacing = 10
        pillRow.distribution = .fillEqually
        pillRow.translatesAutoresizingMaskIntoConstraints = false
        networkCard.addSubview(pillRow)

        // Last checked label
        let checkedLabel = UILabel()
        checkedLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        checkedLabel.textColor = textColor.withAlphaComponent(0.4)
        checkedLabel.textAlignment = .right
        checkedLabel.translatesAutoresizingMaskIntoConstraints = false
        networkCard.addSubview(checkedLabel)
        self.lastCheckedLabel = checkedLabel

        NSLayoutConstraint.activate([
            networkHeader.topAnchor.constraint(equalTo: networkCard.topAnchor, constant: 16),
            networkHeader.leadingAnchor.constraint(equalTo: networkCard.leadingAnchor, constant: 16),

            refresh.centerYAnchor.constraint(equalTo: networkHeader.centerYAnchor),
            refresh.trailingAnchor.constraint(equalTo: networkCard.trailingAnchor, constant: -16),
            refresh.widthAnchor.constraint(equalToConstant: 32),
            refresh.heightAnchor.constraint(equalToConstant: 32),

            pillRow.topAnchor.constraint(equalTo: networkHeader.bottomAnchor, constant: 14),
            pillRow.leadingAnchor.constraint(equalTo: networkCard.leadingAnchor, constant: 16),
            pillRow.trailingAnchor.constraint(equalTo: networkCard.trailingAnchor, constant: -16),

            checkedLabel.topAnchor.constraint(equalTo: pillRow.bottomAnchor, constant: 10),
            checkedLabel.trailingAnchor.constraint(equalTo: networkCard.trailingAnchor, constant: -16),
            checkedLabel.bottomAnchor.constraint(equalTo: networkCard.bottomAnchor, constant: -14),
        ])

        // DEVICES card
        let devicesCard = createCard()
        contentView.addSubview(devicesCard)

        let devicesHeader = createSectionHeader(icon: "desktopcomputer", title: "DEVICES")
        devicesCard.addSubview(devicesHeader)

        // Microphone row
        let micRow = createDeviceRow(
            icon: "mic.fill",
            text: getMicrophoneName()
        )
        devicesCard.addSubview(micRow)

        // Camera row (only in video mode)
        let cameraRow = createDeviceRow(
            icon: "video.fill",
            text: isAudioModeOnly ? "Disabled (Audio Only)" : getCameraName()
        )
        devicesCard.addSubview(cameraRow)

        // Separator
        let separator = UIView()
        separator.backgroundColor = UIColor.systemGray5
        separator.translatesAutoresizingMaskIntoConstraints = false
        devicesCard.addSubview(separator)

        NSLayoutConstraint.activate([
            devicesHeader.topAnchor.constraint(equalTo: devicesCard.topAnchor, constant: 16),
            devicesHeader.leadingAnchor.constraint(equalTo: devicesCard.leadingAnchor, constant: 16),

            micRow.topAnchor.constraint(equalTo: devicesHeader.bottomAnchor, constant: 12),
            micRow.leadingAnchor.constraint(equalTo: devicesCard.leadingAnchor, constant: 16),
            micRow.trailingAnchor.constraint(equalTo: devicesCard.trailingAnchor, constant: -16),

            separator.topAnchor.constraint(equalTo: micRow.bottomAnchor, constant: 10),
            separator.leadingAnchor.constraint(equalTo: devicesCard.leadingAnchor, constant: 16),
            separator.trailingAnchor.constraint(equalTo: devicesCard.trailingAnchor, constant: -16),
            separator.heightAnchor.constraint(equalToConstant: 1),

            cameraRow.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 10),
            cameraRow.leadingAnchor.constraint(equalTo: devicesCard.leadingAnchor, constant: 16),
            cameraRow.trailingAnchor.constraint(equalTo: devicesCard.trailingAnchor, constant: -16),
            cameraRow.bottomAnchor.constraint(equalTo: devicesCard.bottomAnchor, constant: -16),
        ])

        // Card layout
        NSLayoutConstraint.activate([
            networkCard.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            networkCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            networkCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            devicesCard.topAnchor.constraint(equalTo: networkCard.bottomAnchor, constant: 16),
            devicesCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            devicesCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            devicesCard.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -20),
        ])
    }

    // MARK: - Component Builders

    private func createCard() -> UIView {
        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 14
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor.systemGray5.cgColor
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOffset = CGSize(width: 0, height: 1)
        card.layer.shadowRadius = 4
        card.layer.shadowOpacity = 0.06
        card.translatesAutoresizingMaskIntoConstraints = false
        return card
    }

    private func createSectionHeader(icon: String, title: String) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let iconView = UIImageView(image: UIImage(systemName: icon, withConfiguration: iconConfig))
        iconView.tintColor = textColor
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = title
        label.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        label.textColor = textColor
        label.translatesAutoresizingMaskIntoConstraints = false

        row.addArrangedSubview(iconView)
        row.addArrangedSubview(label)
        return row
    }

    private func createStatPill(label labelText: String, value: String, color: UIColor) -> UIView {
        let pill = UIView()
        pill.backgroundColor = pageBg
        pill.layer.cornerRadius = 10
        pill.layer.borderWidth = 1
        pill.layer.borderColor = UIColor.systemGray5.cgColor
        pill.translatesAutoresizingMaskIntoConstraints = false

        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 6
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(row)

        let nameLabel = UILabel()
        nameLabel.text = labelText
        nameLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        nameLabel.textColor = textColor.withAlphaComponent(0.7)

        let dot = UIView()
        dot.backgroundColor = color
        dot.layer.cornerRadius = 5
        dot.tag = 1002
        dot.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: 10),
            dot.heightAnchor.constraint(equalToConstant: 10),
        ])

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        valueLabel.textColor = color
        valueLabel.tag = 1001

        row.addArrangedSubview(nameLabel)
        row.addArrangedSubview(dot)
        row.addArrangedSubview(valueLabel)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: pill.topAnchor, constant: 10),
            row.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -10),
            row.centerXAnchor.constraint(equalTo: pill.centerXAnchor),
            row.leadingAnchor.constraint(greaterThanOrEqualTo: pill.leadingAnchor, constant: 10),
        ])

        return pill
    }

    private func createDeviceRow(icon: String, text: String) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 10
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let iconView = UIImageView(image: UIImage(systemName: icon, withConfiguration: iconConfig))
        iconView.tintColor = textColor.withAlphaComponent(0.5)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 20),
        ])

        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = textColor
        label.translatesAutoresizingMaskIntoConstraints = false

        row.addArrangedSubview(iconView)
        row.addArrangedSubview(label)
        return row
    }

    // MARK: - Network Stats (uses Daily SDK's callClient.networkStatistics)

    private func refreshNetworkStats() {
        networkCheckTime = Date()

        // Connectivity from call state
        let callState = callClient.callState
        let hasSDKStats = callClient.networkStatistics != nil
        print("[NetworkDebug] Settings refreshNetworkStats — callState: \(callState), hasSDKStats: \(hasSDKStats), cachedQuality: '\(lastNetworkQuality)'")
        if let stats = callClient.networkStatistics {
            print("[NetworkDebug]   SDK stats — threshold: \(stats.threshold), quality: \(stats.quality)")
        }
        let isConnected = callState == .joined
        let connColor: UIColor
        let connText: String

        switch callState {
        case .joined:
            connColor = .systemGreen
            connText = "Connected"
        case .joining:
            connColor = .systemOrange
            connText = "Connecting..."
        case .leaving:
            connColor = .systemOrange
            connText = "Leaving..."
        default:
            connColor = .systemRed
            connText = "Disconnected"
        }

        connectivityLabel?.text = connText
        connectivityLabel?.textColor = connColor
        connectivityDot?.backgroundColor = connColor

        // Quality: try SDK stats first, fall back to cached quality, or show unknown if disconnected
        if !isConnected {
            // Not connected — quality is N/A
            let naColor = UIColor.systemGray
            qualityLabel?.text = "N/A"
            qualityLabel?.textColor = naColor
            qualityDot?.backgroundColor = naColor
        } else if let stats = callClient.networkStatistics {
            // SDK has stats — use quality score (0-100) since threshold enum is unreliable
            let qualityScore = stats.quality
            let mapped = qualityFromScore(qualityScore)
            let qColor = qualityColor(mapped)

            qualityLabel?.text = qualityText(mapped)
            qualityLabel?.textColor = qColor
            qualityDot?.backgroundColor = qColor
            lastNetworkQuality = mapped

            print("[NetworkDebug]   using qualityScore: \(qualityScore), mapped: '\(mapped)'")
        } else {
            // Connected but no SDK stats yet — use cached quality from delegate callbacks
            let qColor = qualityColor(lastNetworkQuality)
            qualityLabel?.text = qualityText(lastNetworkQuality)
            qualityLabel?.textColor = qColor
            qualityDot?.backgroundColor = qColor
        }

        updateLastCheckedLabel()
        startCountdownTimer()

        // Spin the refresh button
        if let btn = refreshButton {
            let spin = CABasicAnimation(keyPath: "transform.rotation.z")
            spin.toValue = Double.pi * 2
            spin.duration = 0.5
            spin.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            btn.layer.add(spin, forKey: "spin")
        }
    }

    private func startCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self, self.view.window != nil else { timer.invalidate(); return }
            self.updateLastCheckedLabel()
        }
    }

    private func updateLastCheckedLabel() {
        let elapsed = Int(Date().timeIntervalSince(networkCheckTime))
        let nextIn = max(0, 30 - elapsed)
        lastCheckedLabel?.text = "Last checked \(elapsed)s ago \u{00B7} Next in \(nextIn)s"

        if elapsed >= 30 {
            refreshNetworkStats()
        }
    }

    /// Called from DailyCallViewController when the SDK fires networkStatsUpdated
    func updateNetworkStats(_ stats: NetworkStats) {
        let qualityScore = stats.quality // 0-100
        let mapped = qualityFromScore(qualityScore)
        let qColor = qualityColor(mapped)

        qualityLabel?.text = qualityText(mapped)
        qualityLabel?.textColor = qColor
        qualityDot?.backgroundColor = qColor
        lastNetworkQuality = mapped

        // Refresh connectivity state and timestamp
        networkCheckTime = Date()
        let isConnected = callClient.callState == .joined
        connectivityLabel?.text = isConnected ? "Connected" : "Disconnected"
        connectivityLabel?.textColor = isConnected ? .systemGreen : .systemRed
        connectivityDot?.backgroundColor = isConnected ? .systemGreen : .systemRed
    }

    /// Fallback for legacy string-based quality updates
    func updateNetworkQuality(_ quality: String) {
        lastNetworkQuality = quality
        let color = qualityColor(quality)
        qualityLabel?.text = qualityText(quality)
        qualityLabel?.textColor = color
        qualityDot?.backgroundColor = color
    }

    // MARK: - Helpers

    /// Convert Daily SDK Threshold enum to display text
    private func thresholdText(_ threshold: Threshold) -> String {
        switch threshold {
        case .good: return "Good"
        case .low: return "Poor"
        case .veryLow: return "Very Poor"
        @unknown default: return "Unknown"
        }
    }

    /// Convert Daily SDK Threshold enum to display color
    private func thresholdColor(_ threshold: Threshold) -> UIColor {
        switch threshold {
        case .good: return .systemGreen
        case .low: return .systemOrange
        case .veryLow: return .systemRed
        @unknown default: return .systemGray
        }
    }

    /// Convert quality score (0-100) to state string
    private func qualityFromScore(_ score: Int) -> String {
        if score >= 70 { return "good" }
        if score >= 50 { return "low" }
        return "very-low"
    }

    /// Convert quality string to display text
    private func qualityText(_ quality: String) -> String {
        switch quality {
        case "very-low": return "Very Poor"
        case "low": return "Poor"
        default: return "Good"
        }
    }

    /// Fallback: convert legacy string quality to color
    private func qualityColor(_ quality: String) -> UIColor {
        switch quality {
        case "very-low": return .systemRed
        case "low": return .systemOrange
        default: return .systemGreen
        }
    }

    private func getMicrophoneName() -> String {
        let session = AVAudioSession.sharedInstance()
        if let input = session.currentRoute.inputs.first {
            return input.portName
        }
        return "Default Microphone"
    }

    private func getCameraName() -> String {
        let camEnabled = callClient.inputs.camera.isEnabled
        if !camEnabled { return "Camera Off" }
        return "Front Camera"
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func refreshTapped() {
        refreshNetworkStats()
    }
}

