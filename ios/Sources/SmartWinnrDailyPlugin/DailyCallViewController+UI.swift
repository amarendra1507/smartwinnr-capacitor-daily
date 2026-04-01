//
//  DailyCallViewController+UI.swift
//  SmartwinnrCapacitorDaily
//

import UIKit
import Daily

extension DailyCallViewController {

    func initializeUI() {
        guard !isUIInitialized else { return }
        isUIInitialized = true
        setupUI()
        setupCallClient()
    }

    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1.0)
        setupHeader()
        setupContentContainer()
        setupCoachingTitle()
        setupTimerLabel()
        setupVideoTiles()
        setupControlsRow()
        setupConstraints()
    }

    // MARK: - Header

    private func setupHeader() {
        let brandColor = UIColor(red: 0, green: 0, blue: 201.0/255.0, alpha: 1.0) // rgb(0,0,201)

        // Header bar with brand color
        headerView.backgroundColor = brandColor
        headerView.translatesAutoresizingMaskIntoConstraints = false

        // Back button — white on brand
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        headerBackButton.setImage(UIImage(systemName: "chevron.left", withConfiguration: config), for: .normal)
        headerBackButton.tintColor = .white
        headerBackButton.translatesAutoresizingMaskIntoConstraints = false
        headerBackButton.addTarget(self, action: #selector(headerBackTapped), for: .touchUpInside)
        headerView.addSubview(headerBackButton)

        // Title — white on brand
        headerTitleLabel.text = coachingTitle
        headerTitleLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        headerTitleLabel.textColor = .white
        headerTitleLabel.textAlignment = .center
        headerTitleLabel.lineBreakMode = .byTruncatingTail
        headerTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(headerTitleLabel)

        // Status bar background (extends brand color behind status bar)
        let statusBarBg = UIView()
        statusBarBg.backgroundColor = brandColor
        statusBarBg.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusBarBg)
        view.addSubview(headerView)

        NSLayoutConstraint.activate([
            // Status bar background fills from screen top to safe area top
            statusBarBg.topAnchor.constraint(equalTo: view.topAnchor),
            statusBarBg.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            statusBarBg.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            statusBarBg.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),

            // Header below safe area
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 44),

            headerBackButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 8),
            headerBackButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            headerBackButton.widthAnchor.constraint(equalToConstant: 44),
            headerBackButton.heightAnchor.constraint(equalToConstant: 44),

            headerTitleLabel.leadingAnchor.constraint(equalTo: headerBackButton.trailingAnchor, constant: 4),
            headerTitleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -56),
            headerTitleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
        ])
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent // White status bar text on brand color
    }

    @objc func headerBackTapped() {
        // Show confirmation before leaving
        let alert = UIAlertController(
            title: "Leave Session?",
            message: "Are you sure you want to end this role play session?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Leave", style: .destructive) { [weak self] _ in
            self?.endRolePlayTapped()
        })
        present(alert, animated: true)
    }

    // MARK: - Content Container

    private func setupContentContainer() {
        newContentContainerView.backgroundColor = .clear
        newContentContainerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(newContentContainerView)
    }

    // MARK: - Coaching Title

    private func setupCoachingTitle() {
        newCoachingTitleLabel.text = coachingTitle
        newCoachingTitleLabel.textAlignment = .center
        newCoachingTitleLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        newCoachingTitleLabel.textColor = UIColor.systemBlue
        newCoachingTitleLabel.backgroundColor = .clear
        newCoachingTitleLabel.numberOfLines = 2
        newCoachingTitleLabel.lineBreakMode = .byWordWrapping
        newCoachingTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        newCoachingTitleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        newCoachingTitleLabel.setContentHuggingPriority(.required, for: .vertical)
        newContentContainerView.addSubview(newCoachingTitleLabel)
    }

    // MARK: - Timer

    private func setupTimerLabel() {
        newTimerLabel.text = "  00:00  /  05:00  "
        newTimerLabel.textAlignment = .center
        newTimerLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        newTimerLabel.textColor = .white
        newTimerLabel.backgroundColor = UIColor.systemBlue
        newTimerLabel.layer.cornerRadius = 18
        newTimerLabel.layer.masksToBounds = true
        newTimerLabel.translatesAutoresizingMaskIntoConstraints = false
        newTimerLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        newContentContainerView.addSubview(newTimerLabel)
    }

    // MARK: - Video Tiles

    private func setupVideoTiles() {
        let cornerRadius: CGFloat = 12
        let tileBg = UIColor(red: 0.97, green: 0.98, blue: 0.98, alpha: 1.0)

        for container in [newLocalVideoContainer, newRemoteVideoContainer] {
            container.backgroundColor = tileBg
            container.layer.cornerRadius = cornerRadius
            container.layer.borderWidth = 1
            container.layer.borderColor = UIColor.systemGray4.cgColor
            container.layer.shadowColor = UIColor.black.cgColor
            container.layer.shadowOffset = CGSize(width: 0, height: 2)
            container.layer.shadowRadius = 8
            container.layer.shadowOpacity = 0.12
            container.translatesAutoresizingMaskIntoConstraints = false
        }

        for v in [newLocalVideoView, newRemoteVideoView] {
            v.backgroundColor = .black
            v.layer.cornerRadius = cornerRadius
            v.layer.masksToBounds = true
            v.videoScaleMode = .fit
            v.contentMode = .scaleAspectFit
            v.translatesAutoresizingMaskIntoConstraints = false
        }

        newLocalVideoContainer.addSubview(newLocalVideoView)
        newRemoteVideoContainer.addSubview(newRemoteVideoView)

        // Audio-only mode: add avatar placeholders on top of video views
        if isAudioModeOnly {
            setupAvatarPlaceholder(localAvatarView, in: newLocalVideoContainer,
                                   name: userName, imageURL: userProfileImageURL)
            setupAvatarPlaceholder(remoteAvatarView, in: newRemoteVideoContainer,
                                   name: coachName, imageURL: coachProfileImageURL)
            // Hide the actual video views
            newLocalVideoView.isHidden = true
            newRemoteVideoView.isHidden = true
        }

        setupLocalTile()
        setupRemoteTile()

        updateStackViewForCurrentOrientation()
        newMainStackView.distribution = .fillEqually
        newMainStackView.alignment = .fill
        newMainStackView.translatesAutoresizingMaskIntoConstraints = false

        newMainStackView.addArrangedSubview(localTileWrapper)
        newMainStackView.addArrangedSubview(remoteTileWrapper)
        newContentContainerView.addSubview(newMainStackView)
    }

    // MARK: - Avatar Placeholder (audio-only mode)

    private func setupAvatarPlaceholder(_ avatarView: UIView, in container: UIView,
                                         name: String, imageURL: String?) {
        avatarView.backgroundColor = UIColor(red: 0.23, green: 0.31, blue: 0.39, alpha: 1.0) // #3a4f64
        avatarView.layer.cornerRadius = 12
        avatarView.layer.masksToBounds = true
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(avatarView)

        NSLayoutConstraint.activate([
            avatarView.topAnchor.constraint(equalTo: container.topAnchor),
            avatarView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            avatarView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            avatarView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        // Avatar image (circular)
        let imageSize: CGFloat = 64
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = imageSize / 2
        imageView.layer.borderWidth = 2
        imageView.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        imageView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.addSubview(imageView)

        // Load image or show initials
        if let urlStr = imageURL, let url = URL(string: urlStr) {
            loadProfileImage(from: url) { [weak imageView] img in
                DispatchQueue.main.async { imageView?.image = img }
            }
        } else {
            imageView.image = generateDefaultProfileImage(for: name)
        }

        // Audio icon badge (shows mic icon to indicate audio-only)
        let micBadge = UIView()
        micBadge.backgroundColor = UIColor(red: 0.06, green: 0.73, blue: 0.51, alpha: 0.2) // green tint
        micBadge.layer.cornerRadius = 16
        micBadge.layer.borderWidth = 1
        micBadge.layer.borderColor = UIColor(red: 0.06, green: 0.73, blue: 0.51, alpha: 0.3).cgColor
        micBadge.translatesAutoresizingMaskIntoConstraints = false
        avatarView.addSubview(micBadge)

        let micIcon = UIImageView(image: UIImage(systemName: "mic.fill"))
        micIcon.tintColor = UIColor(red: 0.06, green: 0.73, blue: 0.51, alpha: 1.0)
        micIcon.contentMode = .scaleAspectFit
        micIcon.translatesAutoresizingMaskIntoConstraints = false
        micBadge.addSubview(micIcon)

        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor, constant: -10),
            imageView.widthAnchor.constraint(equalToConstant: imageSize),
            imageView.heightAnchor.constraint(equalToConstant: imageSize),

            micBadge.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            micBadge.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 10),
            micBadge.widthAnchor.constraint(equalToConstant: 32),
            micBadge.heightAnchor.constraint(equalToConstant: 32),

            micIcon.centerXAnchor.constraint(equalTo: micBadge.centerXAnchor),
            micIcon.centerYAnchor.constraint(equalTo: micBadge.centerYAnchor),
            micIcon.widthAnchor.constraint(equalToConstant: 18),
            micIcon.heightAnchor.constraint(equalToConstant: 18),
        ])
    }

    // MARK: - Local Tile

    private func setupLocalTile() {
        localTileWrapper.translatesAutoresizingMaskIntoConstraints = false
        localTileWrapper.addSubview(newLocalVideoContainer)

        localIndicatorRow.translatesAutoresizingMaskIntoConstraints = false
        localTileWrapper.addSubview(localIndicatorRow)

        setupMediaControlButton(newMicButton, iconName: "mic.fill")
        setupMediaControlButton(newCameraButton, iconName: "video.fill")

        // Hide camera button in audio-only mode
        newCameraButton.isHidden = isAudioModeOnly

        let controlsStack = UIStackView(arrangedSubviews: [newMicButton, newCameraButton])
        controlsStack.axis = .horizontal
        controlsStack.spacing = 6
        controlsStack.translatesAutoresizingMaskIntoConstraints = false

        newLocalParticipantLabel.text = userName
        newLocalParticipantLabel.textAlignment = .center
        newLocalParticipantLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        newLocalParticipantLabel.textColor = UIColor(red: 0.29, green: 0.31, blue: 0.34, alpha: 1.0)
        newLocalParticipantLabel.translatesAutoresizingMaskIntoConstraints = false
        newLocalParticipantLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        let rightStack = UIStackView(arrangedSubviews: [controlsStack, newLocalParticipantLabel])
        rightStack.axis = .horizontal
        rightStack.spacing = 8
        rightStack.alignment = .center
        rightStack.translatesAutoresizingMaskIntoConstraints = false
        localIndicatorRow.addSubview(rightStack)

        NSLayoutConstraint.activate([
            newLocalVideoContainer.topAnchor.constraint(equalTo: localTileWrapper.topAnchor),
            newLocalVideoContainer.leadingAnchor.constraint(equalTo: localTileWrapper.leadingAnchor),
            newLocalVideoContainer.trailingAnchor.constraint(equalTo: localTileWrapper.trailingAnchor),

            newLocalVideoView.topAnchor.constraint(equalTo: newLocalVideoContainer.topAnchor),
            newLocalVideoView.leadingAnchor.constraint(equalTo: newLocalVideoContainer.leadingAnchor),
            newLocalVideoView.trailingAnchor.constraint(equalTo: newLocalVideoContainer.trailingAnchor),
            newLocalVideoView.bottomAnchor.constraint(equalTo: newLocalVideoContainer.bottomAnchor),

            localIndicatorRow.topAnchor.constraint(equalTo: newLocalVideoContainer.bottomAnchor, constant: 2),
            localIndicatorRow.leadingAnchor.constraint(equalTo: localTileWrapper.leadingAnchor),
            localIndicatorRow.trailingAnchor.constraint(equalTo: localTileWrapper.trailingAnchor),
            localIndicatorRow.heightAnchor.constraint(equalToConstant: 32),
            localIndicatorRow.bottomAnchor.constraint(equalTo: localTileWrapper.bottomAnchor),

            rightStack.trailingAnchor.constraint(equalTo: localIndicatorRow.trailingAnchor),
            rightStack.centerYAnchor.constraint(equalTo: localIndicatorRow.centerYAnchor),
        ])
    }

    // MARK: - Remote Tile

    private func setupRemoteTile() {
        remoteTileWrapper.translatesAutoresizingMaskIntoConstraints = false
        remoteTileWrapper.addSubview(newRemoteVideoContainer)

        remoteIndicatorRow.translatesAutoresizingMaskIntoConstraints = false
        remoteTileWrapper.addSubview(remoteIndicatorRow)

        newRemoteParticipantLabel.text = coachName
        newRemoteParticipantLabel.textAlignment = .center
        newRemoteParticipantLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        newRemoteParticipantLabel.textColor = UIColor(red: 0.29, green: 0.31, blue: 0.34, alpha: 1.0)
        newRemoteParticipantLabel.translatesAutoresizingMaskIntoConstraints = false
        newRemoteParticipantLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        remoteIndicatorRow.addSubview(newRemoteParticipantLabel)

        NSLayoutConstraint.activate([
            newRemoteVideoContainer.topAnchor.constraint(equalTo: remoteTileWrapper.topAnchor),
            newRemoteVideoContainer.leadingAnchor.constraint(equalTo: remoteTileWrapper.leadingAnchor),
            newRemoteVideoContainer.trailingAnchor.constraint(equalTo: remoteTileWrapper.trailingAnchor),

            newRemoteVideoView.topAnchor.constraint(equalTo: newRemoteVideoContainer.topAnchor),
            newRemoteVideoView.leadingAnchor.constraint(equalTo: newRemoteVideoContainer.leadingAnchor),
            newRemoteVideoView.trailingAnchor.constraint(equalTo: newRemoteVideoContainer.trailingAnchor),
            newRemoteVideoView.bottomAnchor.constraint(equalTo: newRemoteVideoContainer.bottomAnchor),

            remoteIndicatorRow.topAnchor.constraint(equalTo: newRemoteVideoContainer.bottomAnchor, constant: 2),
            remoteIndicatorRow.leadingAnchor.constraint(equalTo: remoteTileWrapper.leadingAnchor),
            remoteIndicatorRow.trailingAnchor.constraint(equalTo: remoteTileWrapper.trailingAnchor),
            remoteIndicatorRow.heightAnchor.constraint(equalToConstant: 32),
            remoteIndicatorRow.bottomAnchor.constraint(equalTo: remoteTileWrapper.bottomAnchor),

            newRemoteParticipantLabel.trailingAnchor.constraint(equalTo: remoteIndicatorRow.trailingAnchor),
            newRemoteParticipantLabel.centerYAnchor.constraint(equalTo: remoteIndicatorRow.centerYAnchor),
        ])
    }

    // MARK: - Media Control Button

    private func setupMediaControlButton(_ button: UIButton, iconName: String) {
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        button.setImage(UIImage(systemName: iconName, withConfiguration: config), for: .normal)
        button.tintColor = UIColor(red: 0.29, green: 0.31, blue: 0.34, alpha: 1.0)
        button.backgroundColor = UIColor(red: 0.91, green: 0.93, blue: 0.93, alpha: 1.0)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: button == newMicButton ? #selector(didTapToggleMicrophone) : #selector(didTapToggleCamera), for: .touchUpInside)
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 42),
            button.heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    // MARK: - Controls Row

    private func setupControlsRow() {
        newEndRolePlayButton.setTitle("End Role Play", for: .normal)
        newEndRolePlayButton.setTitleColor(.white, for: .normal)
        newEndRolePlayButton.backgroundColor = UIColor.systemRed
        newEndRolePlayButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        newEndRolePlayButton.layer.cornerRadius = 22
        newEndRolePlayButton.layer.masksToBounds = true
        newEndRolePlayButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        newEndRolePlayButton.translatesAutoresizingMaskIntoConstraints = false
        newEndRolePlayButton.addTarget(self, action: #selector(endRolePlayTapped), for: .touchUpInside)
        newEndRolePlayButton.addTarget(self, action: #selector(buttonTouchDown), for: .touchDown)
        newEndRolePlayButton.addTarget(self, action: #selector(buttonTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])

        newScreenShareButton.setTitleColor(.white, for: .normal)
        newScreenShareButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        newScreenShareButton.layer.cornerRadius = 22
        newScreenShareButton.layer.masksToBounds = true
        newScreenShareButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        newScreenShareButton.translatesAutoresizingMaskIntoConstraints = false
        newScreenShareButton.addTarget(self, action: #selector(screenShareTapped), for: .touchUpInside)
        newScreenShareButton.addTarget(self, action: #selector(buttonTouchDown), for: .touchDown)
        newScreenShareButton.addTarget(self, action: #selector(buttonTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        newScreenShareButton.isHidden = !enableScreenShare || isAudioModeOnly

        controlsRow.axis = .horizontal
        controlsRow.spacing = 16
        controlsRow.alignment = .center
        controlsRow.distribution = .fill
        controlsRow.translatesAutoresizingMaskIntoConstraints = false
        controlsRow.addArrangedSubview(newScreenShareButton)
        controlsRow.addArrangedSubview(newEndRolePlayButton)
        newContentContainerView.addSubview(controlsRow)
        updateScreenShareButton()
    }

    // MARK: - Constraints

    private func setupConstraints() {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad

        // iPad: limit container width for clean layout
        // iPhone: fill screen width
        let containerMaxWidth: CGFloat = isIPad ? 700 : .greatestFiniteMagnitude

        NSLayoutConstraint.activate([
            newContentContainerView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 8),
            newContentContainerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            newContentContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            newContentContainerView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 16),
            newContentContainerView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16),
        ])

        if isIPad {
            let wc = newContentContainerView.widthAnchor.constraint(equalToConstant: containerMaxWidth)
            wc.priority = UILayoutPriority(999)
            wc.isActive = true
        } else {
            NSLayoutConstraint.activate([
                newContentContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
                newContentContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            ])
        }

        // Title + timer at top
        NSLayoutConstraint.activate([
            newCoachingTitleLabel.topAnchor.constraint(equalTo: newContentContainerView.topAnchor, constant: 4),
            newCoachingTitleLabel.leadingAnchor.constraint(equalTo: newContentContainerView.leadingAnchor),
            newCoachingTitleLabel.trailingAnchor.constraint(equalTo: newContentContainerView.trailingAnchor),

            newTimerLabel.topAnchor.constraint(equalTo: newCoachingTitleLabel.bottomAnchor, constant: 8),
            newTimerLabel.centerXAnchor.constraint(equalTo: newContentContainerView.centerXAnchor),
            newTimerLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
            newTimerLabel.heightAnchor.constraint(equalToConstant: 36),
        ])

        // Stack view — centered vertically between timer and controls
        NSLayoutConstraint.activate([
            newMainStackView.leadingAnchor.constraint(equalTo: newContentContainerView.leadingAnchor),
            newMainStackView.trailingAnchor.constraint(equalTo: newContentContainerView.trailingAnchor),
            newMainStackView.topAnchor.constraint(greaterThanOrEqualTo: newTimerLabel.bottomAnchor, constant: 8),
            newMainStackView.bottomAnchor.constraint(lessThanOrEqualTo: controlsRow.topAnchor, constant: -8),
        ])

        // Center the stack in available space between timer and controls
        let centerY = newMainStackView.centerYAnchor.constraint(equalTo: newContentContainerView.centerYAnchor)
        centerY.priority = UILayoutPriority(750)
        centerY.isActive = true

        // Controls at bottom
        NSLayoutConstraint.activate([
            controlsRow.centerXAnchor.constraint(equalTo: newContentContainerView.centerXAnchor),
            controlsRow.bottomAnchor.constraint(equalTo: newContentContainerView.bottomAnchor, constant: -4),
            controlsRow.heightAnchor.constraint(equalToConstant: 44),
            newEndRolePlayButton.heightAnchor.constraint(equalToConstant: 44),
            newScreenShareButton.heightAnchor.constraint(equalToConstant: 44),
        ])

        applyVideoAspectRatio(9.0 / 16.0)
    }

    private func applyVideoAspectRatio(_ multiplier: CGFloat) {
        localVideoAspectConstraint?.isActive = false
        remoteVideoAspectConstraint?.isActive = false

        localVideoAspectConstraint = newLocalVideoContainer.heightAnchor.constraint(
            equalTo: newLocalVideoContainer.widthAnchor, multiplier: multiplier
        )
        localVideoAspectConstraint?.priority = UILayoutPriority(900) // High but yields to required
        localVideoAspectConstraint?.isActive = true

        remoteVideoAspectConstraint = newRemoteVideoContainer.heightAnchor.constraint(
            equalTo: newRemoteVideoContainer.widthAnchor, multiplier: multiplier
        )
        remoteVideoAspectConstraint?.priority = UILayoutPriority(900)
        remoteVideoAspectConstraint?.isActive = true
    }

    func setupCallClient() {
        updateNewTimer(currentTime: currentTime, maxTime: maxTime)
    }

    // MARK: - Participant Names

    func updateParticipantNames(localName: String?, remoteName: String?) {
        if let localName = localName { newLocalParticipantLabel.text = localName }
        if let remoteName = remoteName { newRemoteParticipantLabel.text = remoteName }
    }

    // MARK: - Profile Images

    func setUserProfileImage(_ image: UIImage) {
        self.userProfileImage = image
        if #available(iOS 15.0, *) { if pipVideoCallViewControllerStorage != nil { setupPictureInPicture() } }
    }
    func setUserProfileImageURL(_ urlString: String) {
        self.userProfileImageURL = urlString
        if #available(iOS 15.0, *) { if pipVideoCallViewControllerStorage != nil { setupPictureInPicture() } }
    }
    func setCoachProfileImage(_ image: UIImage) {
        self.coachProfileImage = image
        if #available(iOS 15.0, *) { if pipVideoCallViewControllerStorage != nil { setupPictureInPicture() } }
    }
    func setCoachProfileImageURL(_ urlString: String) {
        self.coachProfileImageURL = urlString
        if #available(iOS 15.0, *) { if pipVideoCallViewControllerStorage != nil { setupPictureInPicture() } }
    }

    // MARK: - Orientation

    func updateStackViewForCurrentOrientation() {
        let isLandscape = UIDevice.current.orientation.isLandscape || view.frame.width > view.frame.height
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad

        if isLandscape {
            newMainStackView.axis = .horizontal
            newMainStackView.spacing = isIPad ? 16 : 8 // tight spacing = more room for videos
            applyVideoAspectRatio(0.85) // close to 1:1 — fills landscape height
        } else {
            newMainStackView.axis = .vertical
            newMainStackView.spacing = isIPad ? 16 : 10
            applyVideoAspectRatio(isIPad ? 0.65 : 0.5)
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            if self.isUIInitialized { self.updateStackViewForCurrentOrientation() }
        }, completion: nil)
    }

    // MARK: - Video Track

    func attachVideoTrack(_ track: VideoTrack, for participantId: ParticipantID, isLocal: Bool) {
        guard isUIInitialized else { return }

        if isAudioModeOnly {
            // In audio-only mode, don't show video — avatar placeholders are visible
            // Still assign remote track for PiP source (even though main UI hides it)
            if !isLocal {
                newRemoteVideoView.track = track
            }
            return
        }

        if isLocal {
            newLocalVideoView.track = track
        } else {
            newRemoteVideoView.track = track
        }
    }

    // MARK: - Timer Display

    func updateNewTimer(currentTime: TimeInterval, maxTime: TimeInterval) {
        let current = formatTime(currentTime)
        let total = formatTime(maxTime)
        newTimerLabel.text = "  \(current)  /  \(total)  "
        let remaining = maxTime - currentTime
        newTimerLabel.backgroundColor = (remaining <= 60 && remaining > 0) ? .systemRed : .systemBlue
    }

    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Controls

    func updateControls() {
        let micOn = callClient.inputs.microphone.isEnabled
        let camOn = callClient.inputs.camera.isEnabled
        let cfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let activeColor = UIColor(red: 0.29, green: 0.31, blue: 0.34, alpha: 1.0)
        let activeBg = UIColor(red: 0.91, green: 0.93, blue: 0.93, alpha: 1.0)
        let offBg = UIColor.systemRed.withAlphaComponent(0.12)

        newMicButton.setImage(UIImage(systemName: micOn ? "mic.fill" : "mic.slash.fill", withConfiguration: cfg), for: .normal)
        newMicButton.tintColor = micOn ? activeColor : .systemRed
        newMicButton.backgroundColor = micOn ? activeBg : offBg

        newCameraButton.setImage(UIImage(systemName: camOn ? "video.fill" : "video.slash.fill", withConfiguration: cfg), for: .normal)
        newCameraButton.tintColor = camOn ? activeColor : .systemRed
        newCameraButton.backgroundColor = camOn ? activeBg : offBg
    }

    // MARK: - Button Feedback

    @objc func buttonTouchDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) { sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95); sender.alpha = 0.9 }
    }
    @objc func buttonTouchUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) { sender.transform = .identity; sender.alpha = 1.0 }
    }
}
