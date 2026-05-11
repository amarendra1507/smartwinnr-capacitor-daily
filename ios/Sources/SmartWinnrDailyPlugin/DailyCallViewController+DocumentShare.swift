//
//  DailyCallViewController+DocumentShare.swift
//  SmartwinnrCapacitorDaily
//
//  Document-share mode: activated only when `joinCall` is called with
//  `isDocumentShareEnabled: true` (+ a `documentUrl`). In this mode the PDF
//  fills the content area and the user/AI video tiles become small
//  draggable floating PiP overlays. Device-screen recording is requested
//  via `RPSystemBroadcastPickerView` (one-tap Apple system prompt).
//
//  Nothing in this file runs unless the flag is true — the default call UI
//  path is untouched.
//

import UIKit
import PDFKit

/// Shared visual style for the document-share HUD controls.
enum DocumentShareStyle {
    static func pillButton() -> UIButton {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.backgroundColor = UIColor(white: 0, alpha: 0.72)
        b.setTitleColor(.white, for: .normal)
        b.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        b.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        b.layer.cornerRadius = 14
        b.layer.masksToBounds = true
        return b
    }
}

/// Vertical thumbnail sidebar for a PDFView — renders each page as a
/// thumbnail with a "Page N" label beneath, highlights the current page,
/// and jumps the PDFView when a thumbnail is tapped. Matches the iOS /
/// macOS Preview sidebar look.
final class DocumentShareThumbnailList: UIView {

    weak var pdfView: PDFView? {
        didSet {
            unregisterPageObserver(for: oldValue)
            registerPageObserver(for: pdfView)
            reload()
        }
    }

    private let listScrollView = UIScrollView()
    private let stack = UIStackView()
    private var cells: [UIView] = []
    private var selectedIndex: Int = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    deinit { unregisterPageObserver(for: pdfView) }

    private func setup() {
        backgroundColor = .clear

        listScrollView.translatesAutoresizingMaskIntoConstraints = false
        listScrollView.alwaysBounceVertical = true
        listScrollView.showsVerticalScrollIndicator = false
        addSubview(listScrollView)

        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 14
        listScrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            listScrollView.topAnchor.constraint(equalTo: topAnchor),
            listScrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            listScrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            listScrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            // Pin the stack to all four edges of the scroll view's content
            // guide, and lock its width to the scroll view's FRAME width so
            // it never exceeds the drawer (prevents horizontal overflow that
            // was clipping thumbnails on the left).
            stack.topAnchor.constraint(equalTo: listScrollView.contentLayoutGuide.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: listScrollView.contentLayoutGuide.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: listScrollView.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: listScrollView.contentLayoutGuide.trailingAnchor),
            stack.widthAnchor.constraint(equalTo: listScrollView.frameLayoutGuide.widthAnchor),
        ])
    }

    func reload() {
        cells.forEach { $0.removeFromSuperview() }
        cells.removeAll()
        guard let doc = pdfView?.document else { return }

        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            let cell = makeCell(pageIndex: i, page: page)
            stack.addArrangedSubview(cell)
            cells.append(cell)
        }
        syncSelectionFromPdf()
    }

    private func makeCell(pageIndex: Int, page: PDFPage) -> UIView {
        let thumbSize = CGSize(width: 92, height: 120)

        let cell = UIView()
        cell.translatesAutoresizingMaskIntoConstraints = false
        cell.tag = pageIndex
        cell.isUserInteractionEnabled = true

        let frame = UIView()
        frame.translatesAutoresizingMaskIntoConstraints = false
        frame.backgroundColor = .white
        frame.layer.borderColor = UIColor(white: 0.72, alpha: 1.0).cgColor
        frame.layer.borderWidth = 1
        frame.layer.cornerRadius = 3
        frame.clipsToBounds = true
        cell.addSubview(frame)

        let image = UIImageView()
        image.translatesAutoresizingMaskIntoConstraints = false
        image.contentMode = .scaleAspectFit
        image.image = page.thumbnail(of: CGSize(width: thumbSize.width * 2, height: thumbSize.height * 2), for: .cropBox)
        frame.addSubview(image)

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Page \(pageIndex + 1)"
        label.textColor = UIColor(white: 0.35, alpha: 1.0)
        label.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        label.textAlignment = .center
        cell.addSubview(label)

        NSLayoutConstraint.activate([
            // Explicit cell size so Auto Layout doesn't have to guess — it
            // was ambiguous before and caused the stack to overflow.
            cell.widthAnchor.constraint(equalToConstant: thumbSize.width),
            cell.heightAnchor.constraint(equalToConstant: thumbSize.height + 20),

            frame.topAnchor.constraint(equalTo: cell.topAnchor),
            frame.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
            frame.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
            frame.heightAnchor.constraint(equalToConstant: thumbSize.height),

            image.topAnchor.constraint(equalTo: frame.topAnchor),
            image.leadingAnchor.constraint(equalTo: frame.leadingAnchor),
            image.trailingAnchor.constraint(equalTo: frame.trailingAnchor),
            image.bottomAnchor.constraint(equalTo: frame.bottomAnchor),

            label.topAnchor.constraint(equalTo: frame.bottomAnchor, constant: 4),
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
            label.bottomAnchor.constraint(equalTo: cell.bottomAnchor),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleCellTap(_:)))
        cell.addGestureRecognizer(tap)

        return cell
    }

    @objc private func handleCellTap(_ gr: UITapGestureRecognizer) {
        guard let cell = gr.view, let pdfView = pdfView,
              let page = pdfView.document?.page(at: cell.tag) else { return }
        pdfView.go(to: page)
        setSelected(index: cell.tag)
    }

    private func registerPageObserver(for pdfView: PDFView?) {
        guard let pdfView = pdfView else { return }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(pdfPageChanged),
            name: .PDFViewPageChanged,
            object: pdfView
        )
    }
    private func unregisterPageObserver(for pdfView: PDFView?) {
        guard let pdfView = pdfView else { return }
        NotificationCenter.default.removeObserver(
            self,
            name: .PDFViewPageChanged,
            object: pdfView
        )
    }

    @objc private func pdfPageChanged() { syncSelectionFromPdf() }

    private func syncSelectionFromPdf() {
        guard let pdfView = pdfView,
              let doc = pdfView.document,
              let current = pdfView.currentPage,
              let idx = (0..<doc.pageCount).first(where: { doc.page(at: $0) === current }) else { return }
        setSelected(index: idx)
    }

    private func setSelected(index: Int) {
        selectedIndex = index
        for (i, cell) in cells.enumerated() {
            guard let frame = cell.subviews.first else { continue }
            let isSelected = (i == index)
            frame.layer.borderColor = isSelected
                ? UIColor.systemBlue.cgColor
                : UIColor(white: 0.72, alpha: 1.0).cgColor
            frame.layer.borderWidth = isSelected ? 2 : 1
        }
        scrollToSelected(animated: true)
    }

    private func scrollToSelected(animated: Bool) {
        guard cells.indices.contains(selectedIndex) else { return }
        let cell = cells[selectedIndex]
        layoutIfNeeded()
        let target = cell.convert(cell.bounds, to: listScrollView)
        listScrollView.scrollRectToVisible(target.insetBy(dx: 0, dy: -20), animated: animated)
    }
}

/// Overlay view that only claims touches landing on an actual subview (the
/// floating PiP tiles). Empty areas pass through to the PDF view below so
/// the user can swipe/tap the document normally.
final class DocumentSharePassthroughOverlay: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hit = super.hitTest(point, with: event) else { return nil }
        return hit === self ? nil : hit
    }
}

extension DailyCallViewController {

    // MARK: - Public entry point

    /// Called from the `participantJoined` delegate once the AI joins (and
    /// `allParticipantJoined` flips to true). Safe to call multiple times —
    /// a guard prevents double-activation.
    func enterDocumentShareMode() {
        guard isDocumentShareEnabled else { return }
        guard !documentShareActivated else { return }
        guard let urlString = documentUrlString, let pdfURL = URL(string: urlString) else {
            onPdfLoadError?("Invalid documentUrl")
            return
        }
        documentShareActivated = true

        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.view.window != nil else { return }
            self.installDocumentShareLayout(pdfURL: pdfURL)
            self.requestDeviceScreenRecording()
        }
    }

    /// Display name for a resource (falls back to "Document N" when none).
    private func displayTitle(for index: Int) -> String {
        guard index >= 0, index < sharableResourceItems.count else { return "Document" }
        if let name = sharableResourceItems[index].displayName, !name.isEmpty { return name }
        return "Document \(index + 1)"
    }

    // MARK: - Layout installation

    private func installDocumentShareLayout(pdfURL: URL) {
        // 1. The existing two-tile stack must stay *visible* (not isHidden)
        //    because the native PiP uses `newRemoteVideoView` inside this
        //    stack as its `activeVideoCallSourceView`. iOS will only render
        //    inline PiP when that source view is part of the visible window
        //    hierarchy — if it's hidden, PiP defers to the
        //    background-transition path only.
        //
        //    We therefore leave the stack in-place and rely on the opaque
        //    backdrop (added just below) to cover it visually. Interaction
        //    is disabled so taps fall through to the PDF.
        newMainStackView.isHidden = false
        newMainStackView.alpha = 1.0
        newMainStackView.isUserInteractionEnabled = false

        // 2. Build the PDF container.
        let pdfContainer = UIView()
        pdfContainer.translatesAutoresizingMaskIntoConstraints = false
        pdfContainer.backgroundColor = UIColor(white: 0.96, alpha: 1.0)
        pdfContainer.layer.cornerRadius = 12
        pdfContainer.clipsToBounds = true
        newContentContainerView.addSubview(pdfContainer)
        self.pdfContainerView = pdfContainer

        // 2b. Opaque backdrop that covers the entire content area. The
        //     native PiP flow keeps un-hiding `newMainStackView` (it needs
        //     the source view to remain visible for the PiP animation), so
        //     rather than fighting that we just visually cover whatever's
        //     behind the PDF.
        let docShareBackdrop = UIView()
        docShareBackdrop.translatesAutoresizingMaskIntoConstraints = false
        docShareBackdrop.backgroundColor = UIColor(white: 0.94, alpha: 1.0)
        docShareBackdrop.isUserInteractionEnabled = false
        newContentContainerView.insertSubview(docShareBackdrop, belowSubview: pdfContainer)
        NSLayoutConstraint.activate([
            // Cover the whole video-tile zone: from just below the timer to
            // just above the controls row, full width. Matches exactly the
            // strip where `newMainStackView` renders its tiles.
            docShareBackdrop.topAnchor.constraint(equalTo: newTimerLabel.bottomAnchor, constant: 0),
            docShareBackdrop.leadingAnchor.constraint(equalTo: newContentContainerView.leadingAnchor),
            docShareBackdrop.trailingAnchor.constraint(equalTo: newContentContainerView.trailingAnchor),
            docShareBackdrop.bottomAnchor.constraint(equalTo: controlsRow.topAnchor, constant: 0),
        ])

        // 3. Build the PDF view and add it into the container.
        let pdf = DocumentSharePdfView(url: pdfURL)
        pdf.translatesAutoresizingMaskIntoConstraints = false
        pdf.onPageChanged = { [weak self] page, total in
            self?.onPdfPageChanged?(page, total)
            self?.recordPagePresentation(pageNumber: page)
            self?.showPageIndicator(current: page, total: total)
        }
        pdf.onTrackingUpdate = { [weak self] snapshot in
            self?.onPdfTrackingUpdate?(snapshot)
        }
        pdf.onLoadError = { [weak self] message in
            self?.onPdfLoadError?(message)
        }
        pdfContainer.addSubview(pdf)
        self.pdfDocumentView = pdf

        // 4. No custom floating video tile inside the doc-share UI — the
        //    draggable AI/user composite was causing the AI stream to blank
        //    during moves. Video/audio continues to stream via the original
        //    tile wrappers (hidden below the PDF). The only PiP surface is
        //    the native `AVPictureInPictureVideoCallViewController` that
        //    the existing PiP flow manages.
        self.combinedPipContainerView = nil
        self.floatingTilesOverlayView = nil

        // 5b. Top-left control bar (horizontal): thumbnail toggle + (optional)
        //     resource selector. Kept on the left so it doesn't collide with
        //     the top-right floating PiP tiles.
        let topBar = UIStackView()
        topBar.axis = .horizontal
        topBar.spacing = 8
        topBar.alignment = .center
        topBar.translatesAutoresizingMaskIntoConstraints = false
        pdfContainer.addSubview(topBar)

        // Toggle (sidebar button) sits FIRST/left — same relationship the
        // native Preview app has between its sidebar icon and title.
        let toggle = DocumentShareStyle.pillButton()
        toggle.setTitle("☰ Pages", for: .normal)
        toggle.addTarget(self, action: #selector(handleThumbnailToggleTapped), for: .touchUpInside)
        topBar.addArrangedSubview(toggle)
        self.thumbnailToggleButton = toggle

        if sharableResourceItems.count > 1 {
            let selector = DocumentShareStyle.pillButton()
            selector.addTarget(self, action: #selector(handleResourceSelectorTapped), for: .touchUpInside)
            self.resourceSelectorButton = selector
            updateResourceSelectorTitle()
            topBar.addArrangedSubview(selector)
        }

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: pdfContainer.topAnchor, constant: 8),
            topBar.leadingAnchor.constraint(equalTo: pdfContainer.leadingAnchor, constant: 8),
        ])

        // 5c. Thumbnail SIDEBAR (Preview-style) — a vertical sidebar on the
        //     LEFT with a light background matching the page. When the
        //     "☰ Pages" toggle is tapped, the sidebar slides in and the PDF
        //     content shifts right to make room (push-aside, no scrim).
        //     Taps on a thumbnail jump the PDFView to that page.
        let drawer = UIView()
        drawer.translatesAutoresizingMaskIntoConstraints = false
        drawer.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
        drawer.clipsToBounds = true
        pdfContainer.addSubview(drawer)
        self.thumbnailStripView = drawer

        // A hairline on the inside (right) edge separates the sidebar from
        // the page area, matching Preview's look.
        let separator = UIView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.backgroundColor = UIColor(white: 0.82, alpha: 1.0)
        drawer.addSubview(separator)

        let thumbView = DocumentShareThumbnailList()
        thumbView.translatesAutoresizingMaskIntoConstraints = false
        thumbView.backgroundColor = .clear
        drawer.addSubview(thumbView)
        // Binding pdfView triggers reload once its document is set; the
        // onDocumentLoaded callback below covers the async network case.
        thumbView.pdfView = pdf.pdfView
        pdf.onDocumentLoaded = { [weak thumbView] _ in
            thumbView?.reload()
        }

        let drawerLeading = drawer.leadingAnchor.constraint(
            equalTo: pdfContainer.leadingAnchor,
            constant: -thumbnailDrawerWidth
        )
        self.thumbnailDrawerLeadingConstraint = drawerLeading

        NSLayoutConstraint.activate([
            drawerLeading,
            drawer.topAnchor.constraint(equalTo: pdfContainer.topAnchor),
            drawer.bottomAnchor.constraint(equalTo: pdfContainer.bottomAnchor),
            drawer.widthAnchor.constraint(equalToConstant: thumbnailDrawerWidth),

            separator.topAnchor.constraint(equalTo: drawer.topAnchor),
            separator.bottomAnchor.constraint(equalTo: drawer.bottomAnchor),
            separator.trailingAnchor.constraint(equalTo: drawer.trailingAnchor),
            separator.widthAnchor.constraint(equalToConstant: 1),

            thumbView.topAnchor.constraint(equalTo: drawer.topAnchor, constant: 48),
            thumbView.leadingAnchor.constraint(equalTo: drawer.leadingAnchor, constant: 10),
            thumbView.trailingAnchor.constraint(equalTo: drawer.trailingAnchor, constant: -10),
            thumbView.bottomAnchor.constraint(equalTo: drawer.bottomAnchor, constant: -12),
        ])

        // Keep the top bar visible above the drawer so the toggle stays
        // reachable when the sidebar is open.
        pdfContainer.bringSubviewToFront(drawer)
        pdfContainer.bringSubviewToFront(topBar)

        // 6. Activate constraints: PDF fills content area, overlay on top.
        //    The PDF/overlay share a shiftable leading constraint so the
        //    sidebar can push them right when it opens (Preview behavior).
        let pdfLeading = pdf.leadingAnchor.constraint(equalTo: pdfContainer.leadingAnchor)
        self.pdfContentLeadingConstraint = pdfLeading

        NSLayoutConstraint.activate([
            pdfContainer.topAnchor.constraint(equalTo: newTimerLabel.bottomAnchor, constant: 10),
            pdfContainer.leadingAnchor.constraint(equalTo: newContentContainerView.leadingAnchor, constant: 12),
            pdfContainer.trailingAnchor.constraint(equalTo: newContentContainerView.trailingAnchor, constant: -12),
            pdfContainer.bottomAnchor.constraint(equalTo: controlsRow.topAnchor, constant: -10),

            pdf.topAnchor.constraint(equalTo: pdfContainer.topAnchor),
            pdfLeading,
            pdf.trailingAnchor.constraint(equalTo: pdfContainer.trailingAnchor),
            pdf.bottomAnchor.constraint(equalTo: pdfContainer.bottomAnchor),
        ])

        // 5d. Floating page-number pill (like Books / Preview) — fades in on
        //     page change and auto-hides after a moment.
        let indicator = UILabel()
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.backgroundColor = UIColor(white: 0, alpha: 0.72)
        indicator.textColor = .white
        indicator.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        indicator.textAlignment = .center
        indicator.clipsToBounds = true
        indicator.layer.cornerRadius = 11
        indicator.alpha = 0
        indicator.isUserInteractionEnabled = false
        pdfContainer.addSubview(indicator)
        self.pageIndicatorLabel = indicator

        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: pdfContainer.centerXAnchor),
            indicator.bottomAnchor.constraint(equalTo: pdfContainer.bottomAnchor, constant: -14),
            indicator.heightAnchor.constraint(equalToConstant: 22),
            indicator.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
        ])

        // 7. Start loading the PDF (animated fade-in of the new UI).
        pdfContainer.alpha = 0
        pdf.load()
        UIView.animate(withDuration: 0.35) {
            pdfContainer.alpha = 1
        }
    }

    private func relocateTileIntoCombinedContainer(_ tile: UIView, container: UIView) {
        tile.translatesAutoresizingMaskIntoConstraints = false
        // Detach from any stack view that was managing it.
        if let stack = tile.superview as? UIStackView {
            stack.removeArrangedSubview(tile)
        }
        tile.removeFromSuperview()
        // Strip any stale width/height constraints set by earlier call layouts.
        for c in tile.constraints where c.firstItem === tile &&
            (c.firstAttribute == .width || c.firstAttribute == .height) {
            tile.removeConstraint(c)
        }
        container.addSubview(tile)
    }

    // MARK: - PiP container sizing / positioning

    /// A single combined PiP tile (AI large + user small inset) anchored to
    /// the top-right of the PDF area. The user tile is positioned in the
    /// bottom-right inside the container — like an OS-level video-call PiP.
    /// The container moves as one draggable unit.
    private func applyPipTileConstraints() {
        NSLayoutConstraint.deactivate(documentShareTileConstraints)
        documentShareTileConstraints.removeAll()

        guard let pip = combinedPipContainerView else { return }

        let isLandscape = view.bounds.width > view.bounds.height
        let pipSize: CGSize = isLandscape
            ? CGSize(width: 200, height: 140)
            : CGSize(width: 150, height: 200)
        let insetSize: CGSize = isLandscape
            ? CGSize(width: 72, height: 54)
            : CGSize(width: 60, height: 80)
        let padding: CGFloat = 14
        let insetPad: CGFloat = 8

        // Anchored to the root view (self.view) with safe-area insets so the
        // PiP floats above the whole screen, like a native PiP window.
        let safe = view.safeAreaLayoutGuide
        let pipTop = pip.topAnchor.constraint(equalTo: safe.topAnchor, constant: padding)
        let pipTrailing = pip.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -padding)
        let pipW = pip.widthAnchor.constraint(equalToConstant: pipSize.width)
        let pipH = pip.heightAnchor.constraint(equalToConstant: pipSize.height)

        // Remote fills the container.
        let remoteTop = remoteTileWrapper.topAnchor.constraint(equalTo: pip.topAnchor)
        let remoteLeading = remoteTileWrapper.leadingAnchor.constraint(equalTo: pip.leadingAnchor)
        let remoteTrailing = remoteTileWrapper.trailingAnchor.constraint(equalTo: pip.trailingAnchor)
        let remoteBottom = remoteTileWrapper.bottomAnchor.constraint(equalTo: pip.bottomAnchor)

        // Local sits inset in the bottom-right corner above the remote.
        let localTrailing = localTileWrapper.trailingAnchor.constraint(equalTo: pip.trailingAnchor, constant: -insetPad)
        let localBottom = localTileWrapper.bottomAnchor.constraint(equalTo: pip.bottomAnchor, constant: -insetPad)
        let localW = localTileWrapper.widthAnchor.constraint(equalToConstant: insetSize.width)
        let localH = localTileWrapper.heightAnchor.constraint(equalToConstant: insetSize.height)

        // Container position is soft so pan gestures can override.
        [pipTop, pipTrailing].forEach { $0.priority = UILayoutPriority(750) }

        documentShareTileConstraints = [
            pipTop, pipTrailing, pipW, pipH,
            remoteTop, remoteLeading, remoteTrailing, remoteBottom,
            localTrailing, localBottom, localW, localH
        ]
        NSLayoutConstraint.activate(documentShareTileConstraints)

        // Ensure the user-inset tile renders above the full-bleed remote.
        pip.bringSubviewToFront(localTileWrapper)
    }

    // MARK: - Pan gesture (draggable tiles)

    private func installPanGesture(on tile: UIView) {
        // Remove any existing pan gestures we previously installed.
        tile.gestureRecognizers?.forEach { gr in
            if gr is UIPanGestureRecognizer { tile.removeGestureRecognizer(gr) }
        }
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleTilePan(_:)))
        tile.isUserInteractionEnabled = true
        tile.addGestureRecognizer(pan)
    }

    @objc func handleTilePan(_ gesture: UIPanGestureRecognizer) {
        guard let tile = gesture.view else { return }
        // PiP is parented to the root view; drag/clamp happens relative to
        // the full screen bounds.
        let host = view!

        switch gesture.state {
        case .began:
            host.bringSubviewToFront(tile)
            tile.translatesAutoresizingMaskIntoConstraints = true
            deactivatePositionConstraintsForTile(tile)

        case .changed:
            let translation = gesture.translation(in: host)
            var newCenter = CGPoint(
                x: tile.center.x + translation.x,
                y: tile.center.y + translation.y
            )
            let halfW = tile.bounds.width / 2
            let halfH = tile.bounds.height / 2
            newCenter.x = max(halfW, min(host.bounds.width - halfW, newCenter.x))
            newCenter.y = max(halfH, min(host.bounds.height - halfH, newCenter.y))
            tile.center = newCenter
            gesture.setTranslation(.zero, in: host)

        case .ended, .cancelled:
            snapTileToNearestCorner(tile, in: host)

        default:
            break
        }
    }

    private func deactivatePositionConstraintsForTile(_ tile: UIView) {
        let toDrop = documentShareTileConstraints.filter { c in
            guard c.firstItem === tile || c.secondItem === tile else { return false }
            return c.firstAttribute == .top
                || c.firstAttribute == .leading
                || c.firstAttribute == .trailing
                || c.firstAttribute == .bottom
        }
        NSLayoutConstraint.deactivate(toDrop)
        documentShareTileConstraints.removeAll { toDrop.contains($0) }
    }

    private func snapTileToNearestCorner(_ tile: UIView, in host: UIView) {
        let padding: CGFloat = 14
        let w = tile.bounds.width
        let h = tile.bounds.height
        // Respect safe-area insets when the host is the root view (so the
        // PiP doesn't snap under the status bar or home indicator).
        let safe = (host === view) ? view.safeAreaInsets : .zero
        let minX = safe.left + padding + w / 2
        let maxX = host.bounds.width - safe.right - padding - w / 2
        let minY = safe.top + padding + h / 2
        let maxY = host.bounds.height - safe.bottom - padding - h / 2
        let corners: [CGPoint] = [
            CGPoint(x: minX, y: minY),
            CGPoint(x: maxX, y: minY),
            CGPoint(x: minX, y: maxY),
            CGPoint(x: maxX, y: maxY),
        ]
        let center = tile.center
        let nearest = corners.min { a, b in
            hypot(a.x - center.x, a.y - center.y) < hypot(b.x - center.x, b.y - center.y)
        } ?? center

        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.4, animations: {
            tile.center = nearest
        })
    }

    // MARK: - Orientation

    func handleDocumentShareOrientationChange() {
        guard documentShareActivated else { return }
        // Restore Auto Layout for the combined PiP container (it switches to
        // frame-based layout while being dragged).
        combinedPipContainerView?.translatesAutoresizingMaskIntoConstraints = false
        localTileWrapper.translatesAutoresizingMaskIntoConstraints = false
        remoteTileWrapper.translatesAutoresizingMaskIntoConstraints = false
        applyPipTileConstraints()
    }

    // MARK: - Device screen recording (ReplayKit)

    /// Programmatically surfaces Apple's `RPSystemBroadcastPickerView` so the
    /// user can start device-screen recording with a single tap. Reuses the
    /// existing `showBroadcastSystemPicker()` implementation.
    private func requestDeviceScreenRecording() {
        // Delay slightly so the new layout is committed and the PDF spinner
        // is visible before we surface the explanatory prompt.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self = self, self.view.window != nil else { return }
            if self.isScreenSharingActive { return }
            self.showDocumentSharePrompt()
        }
    }

    private func showDocumentSharePrompt() {
        guard !documentSharePromptShown else { return }
        guard presentedViewController == nil else { return }
        documentSharePromptShown = true

        let prompt = DocumentSharePromptViewController()
        prompt.delegate = self
        prompt.modalPresentationStyle = .pageSheet

        if #available(iOS 15.0, *) {
            if let sheet = prompt.sheetPresentationController {
                sheet.detents = [.medium()]
                sheet.preferredCornerRadius = 20
                sheet.prefersGrabberVisible = false
            }
        }

        present(prompt, animated: true)
    }

    // MARK: - Resource selector

    private func updateResourceSelectorTitle() {
        guard let button = resourceSelectorButton else { return }
        let name = displayTitle(for: currentResourceIndex)
        // Use a chevron to hint at the dropdown/picker affordance.
        button.setTitle("\(name)  ▾", for: .normal)
    }

    @objc func handleResourceSelectorTapped() {
        guard sharableResourceItems.count > 1 else { return }

        let sheet = UIAlertController(title: "Select document", message: nil, preferredStyle: .actionSheet)
        for (idx, _) in sharableResourceItems.enumerated() {
            let title = displayTitle(for: idx)
            let marker = (idx == currentResourceIndex) ? "✓ " : "   "
            let action = UIAlertAction(title: "\(marker)\(title)", style: .default) { [weak self] _ in
                self?.switchToResource(at: idx)
            }
            sheet.addAction(action)
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        // iPad needs a popover anchor.
        if let pop = sheet.popoverPresentationController, let anchor = resourceSelectorButton {
            pop.sourceView = anchor
            pop.sourceRect = anchor.bounds
        }
        present(sheet, animated: true)
    }

    /// Tear down the current PDF view and rebuild with the selected resource.
    /// Emits a final tracking snapshot for the outgoing document so the JS
    /// side can record its stats before switching.
    private func switchToResource(at index: Int) {
        guard index != currentResourceIndex else { return }
        guard index >= 0, index < sharableResourceItems.count else { return }
        guard let pdfContainer = pdfContainerView else { return }

        let next = sharableResourceItems[index]
        guard let newURL = URL(string: next.url) else {
            onPdfLoadError?("Invalid documentUrl")
            return
        }

        // Flush stats for the outgoing PDF.
        pdfDocumentView?.finalizeTracking()
        closeActivePagePresentationEntry()

        // Remove the old PDF view.
        pdfDocumentView?.removeFromSuperview()
        pdfDocumentView = nil

        // Update state.
        currentResourceIndex = index
        documentUrlString = next.url
        documentTitle = next.displayName
        updateResourceSelectorTitle()

        // Build a fresh PDF view bound to the same container, wire callbacks,
        // and load.
        let pdf = DocumentSharePdfView(url: newURL)
        pdf.translatesAutoresizingMaskIntoConstraints = false
        pdf.onPageChanged = { [weak self] page, total in
            self?.onPdfPageChanged?(page, total)
            self?.recordPagePresentation(pageNumber: page)
            self?.showPageIndicator(current: page, total: total)
        }
        pdf.onTrackingUpdate = { [weak self] snapshot in
            self?.onPdfTrackingUpdate?(snapshot)
        }
        pdf.onLoadError = { [weak self] message in
            self?.onPdfLoadError?(message)
        }
        pdfContainer.addSubview(pdf)
        pdfDocumentView = pdf

        NSLayoutConstraint.activate([
            pdf.topAnchor.constraint(equalTo: pdfContainer.topAnchor),
            pdf.leadingAnchor.constraint(equalTo: pdfContainer.leadingAnchor),
            pdf.trailingAnchor.constraint(equalTo: pdfContainer.trailingAnchor),
            pdf.bottomAnchor.constraint(equalTo: pdfContainer.bottomAnchor),
        ])

        // Rebind the thumbnail sidebar to the new PDFView.
        if let strip = thumbnailStripView {
            for sub in strip.subviews {
                if let thumb = sub as? DocumentShareThumbnailList {
                    thumb.pdfView = pdf.pdfView
                    pdf.onDocumentLoaded = { [weak thumb] _ in
                        thumb?.reload()
                    }
                }
            }
        }

        // Keep the selector and floating tiles above the new PDF view.
        if let selector = resourceSelectorButton { pdfContainer.bringSubviewToFront(selector) }
        if let toggle = thumbnailToggleButton { pdfContainer.bringSubviewToFront(toggle) }
        if let strip = thumbnailStripView { pdfContainer.bringSubviewToFront(strip) }
        if let pip = combinedPipContainerView { pip.superview?.bringSubviewToFront(pip) }

        pdf.load()
    }

    // MARK: - Finalization

    /// Called on end-call / leave. Flushes final dwell and emits one last
    /// `pdfTrackingUpdate` with `isFinal: true`, plus a final
    /// `pagePresentationTracking` snapshot.
    func finalizeDocumentShareTracking() {
        pdfDocumentView?.finalizeTracking()
        closeActivePagePresentationEntry()
    }

    // MARK: - Page indicator

    func showPageIndicator(current: Int, total: Int) {
        guard let label = pageIndicatorLabel else { return }
        label.text = "  Page \(current) of \(total)  "
        pageIndicatorHideTimer?.invalidate()
        UIView.animate(withDuration: 0.2) { label.alpha = 1.0 }
        pageIndicatorHideTimer = Timer.scheduledTimer(withTimeInterval: 1.6, repeats: false) { [weak self] _ in
            guard let self = self, let label = self.pageIndicatorLabel else { return }
            DispatchQueue.main.async {
                UIView.animate(withDuration: 0.35) { label.alpha = 0 }
            }
        }
    }

    // MARK: - Thumbnail strip

    @objc func handleThumbnailToggleTapped() {
        guard let drawer = thumbnailStripView,
              let leadingC = thumbnailDrawerLeadingConstraint else { return }
        isThumbnailStripVisible.toggle()
        leadingC.constant = isThumbnailStripVisible ? 0 : -thumbnailDrawerWidth
        // Push the PDF content to the right so the sidebar doesn't cover it.
        pdfContentLeadingConstraint?.constant = isThumbnailStripVisible ? thumbnailDrawerWidth : 0
        thumbnailToggleButton?.setTitle(isThumbnailStripVisible ? "✕ Pages" : "☰ Pages", for: .normal)
        UIView.animate(
            withDuration: 0.28,
            delay: 0,
            usingSpringWithDamping: 0.92,
            initialSpringVelocity: 0.4,
            options: [.curveEaseInOut],
            animations: {
                drawer.superview?.layoutIfNeeded()
            }
        )
    }

    // MARK: - Page presentation tracking

    /// Current resource's id — used as `documentId` in every emitted entry.
    private func currentDocumentId() -> String? {
        guard currentResourceIndex >= 0, currentResourceIndex < sharableResourceItems.count else { return nil }
        return sharableResourceItems[currentResourceIndex].id
    }

    /// Called when the active PDF page changes. Closes the previous entry,
    /// opens a new one for `pageNumber`, and emits the cumulative list.
    func recordPagePresentation(pageNumber: Int) {
        guard let documentId = currentDocumentId() else { return }
        closeActivePagePresentationEntry()
        let now = Date().timeIntervalSince1970 * 1000.0
        activePagePresentationEntry = [
            "documentId": documentId,
            "pageNumber": pageNumber,
            "startTime": now,
            "endTime": now,
            "timeSpentMs": 0
        ]
    }

    /// Finalize the currently-open entry (sets endTime / timeSpentMs), push
    /// it to the cumulative list, and emit the full list to JS.
    func closeActivePagePresentationEntry() {
        guard var entry = activePagePresentationEntry else { return }
        let now = Date().timeIntervalSince1970 * 1000.0
        let start = (entry["startTime"] as? Double) ?? now
        entry["endTime"] = now
        entry["timeSpentMs"] = Int(max(0, now - start))
        pagePresentationEntries.append(entry)
        activePagePresentationEntry = nil
        onPagePresentationTracking?(pagePresentationEntries)
    }
}

// MARK: - DocumentSharePromptDelegate

extension DailyCallViewController: DocumentSharePromptDelegate {
    func documentSharePromptDidConfirm() {
        guard !isScreenSharingActive else { return }
        showBroadcastSystemPicker()
    }
}
