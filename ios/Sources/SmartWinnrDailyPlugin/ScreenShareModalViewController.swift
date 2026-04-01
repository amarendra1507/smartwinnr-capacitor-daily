//
//  ScreenShareModalViewController.swift
//  SmartwinnrCapacitorDaily
//
//  Extracted from DailyCallViewController.swift
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

    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let startButton = UIButton()
    private let cancelButton = UIButton()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground

        // Container view
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .clear
        view.addSubview(containerView)

        // Title label
        titleLabel.text = "Screen Share"
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)

        // Description label
        descriptionLabel.text = "Share your screen with other participants in the call. You can share your entire screen or a specific application window."
        descriptionLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(descriptionLabel)

        // Start button
        startButton.setTitle("Start Screen Share", for: .normal)
        startButton.setTitleColor(.white, for: .normal)
        startButton.backgroundColor = UIColor.systemBlue
        startButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        startButton.layer.cornerRadius = 12
        startButton.layer.masksToBounds = true
        startButton.translatesAutoresizingMaskIntoConstraints = false
        startButton.addTarget(self, action: #selector(startButtonTapped), for: .touchUpInside)
        containerView.addSubview(startButton)

        // Cancel button
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.label, for: .normal)
        cancelButton.backgroundColor = UIColor.systemGray5
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        cancelButton.layer.cornerRadius = 12
        cancelButton.layer.masksToBounds = true
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        containerView.addSubview(cancelButton)

        // Constraints
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            containerView.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),

            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),

            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            descriptionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            descriptionLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

            startButton.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 32),
            startButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            startButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            startButton.heightAnchor.constraint(equalToConstant: 50),

            cancelButton.topAnchor.constraint(equalTo: startButton.bottomAnchor, constant: 12),
            cancelButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            cancelButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            cancelButton.heightAnchor.constraint(equalToConstant: 44),
            cancelButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20)
        ])
    }

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
