//
//  DocumentSharePdfView.swift
//  SmartwinnrCapacitorDaily
//
//  PDFKit-based inline PDF renderer with per-page dwell-time tracking.
//  Used only when `isDocumentShareEnabled: true` is passed to `joinCall`.
//

import UIKit
import PDFKit

final class DocumentSharePdfView: UIView {

    // MARK: - Configuration

    private let sourceURL: URL
    private let minDwellMs: Int
    private let emitIntervalMs: Int
    private let requestHeaders: [String: String]

    // MARK: - Callbacks (main thread)

    var onPageChanged: ((_ pageNumber: Int, _ totalPages: Int) -> Void)?
    var onTrackingUpdate: ((_ snapshot: [String: Any]) -> Void)?
    var onLoadError: ((_ message: String) -> Void)?
    var onDocumentLoaded: ((_ document: PDFDocument) -> Void)?

    // MARK: - Subviews

    // Exposed so an external `PDFThumbnailView` can bind to it.
    let pdfView = PDFView()
    private let spinner = UIActivityIndicatorView(style: .large)
    private let errorLabel: UILabel = {
        let l = UILabel()
        l.textAlignment = .center
        l.numberOfLines = 0
        l.textColor = UIColor.systemRed
        l.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        l.isHidden = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Document state

    private var document: PDFDocument?
    private var downloadTask: URLSessionDataTask?
    private var tmpFileURL: URL?

    // MARK: - Tracking state

    private struct PageStat {
        var cumulativeMs: Int = 0
        var lastDwellMs: Int = 0
        var viewed: Bool = false
    }
    private var pageStats: [Int: PageStat] = [:]
    private var currentPage: Int = 1
    private var currentPageEnteredAt: Date?
    private var totalPages: Int = 0
    private var emitTimer: Timer?
    private var isPausedForBackground = false
    private var didFinalize = false

    // MARK: - Init

    init(url: URL,
         minDwellMs: Int = 700,
         emitIntervalMs: Int = 2000,
         headers: [String: String] = [:]) {
        self.sourceURL = url
        self.minDwellMs = minDwellMs
        self.emitIntervalMs = emitIntervalMs
        self.requestHeaders = headers
        super.init(frame: .zero)
        setupViews()
        registerObservers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        downloadTask?.cancel()
        downloadTask = nil
        DispatchQueue.main.async { [weak emitTimer] in
            emitTimer?.invalidate()
        }
        emitTimer = nil
        if let tmp = tmpFileURL {
            try? FileManager.default.removeItem(at: tmp)
        }
    }

    // MARK: - Setup

    private func setupViews() {
        // Neutral gray backdrop (like Preview / Books) so the white page
        // stands out with its own drop-shadow.
        let bg = UIColor(white: 0.86, alpha: 1.0)
        backgroundColor = bg
        layer.cornerRadius = 12
        clipsToBounds = true

        pdfView.translatesAutoresizingMaskIntoConstraints = false
        pdfView.autoScales = true
        // Single-page mode so exactly one page is visible at a time — makes
        // it unambiguous which page is being tracked/recorded. The page-
        // view-controller pager gives a snap swipe transition between pages.
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        pdfView.usePageViewController(true, withViewOptions: nil)
        pdfView.backgroundColor = bg
        pdfView.pageShadowsEnabled = true
        pdfView.pageBreakMargins = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        // Allow pinch zoom between 50% and 400% around the fit scale.
        pdfView.minScaleFactor = 0.5
        pdfView.maxScaleFactor = 4.0
        addSubview(pdfView)

        // Preview-style double-tap to toggle between fit and 2× zoom.
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        pdfView.addGestureRecognizer(doubleTap)

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true
        spinner.startAnimating()
        addSubview(spinner)

        addSubview(errorLabel)

        NSLayoutConstraint.activate([
            pdfView.topAnchor.constraint(equalTo: topAnchor),
            pdfView.leadingAnchor.constraint(equalTo: leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: trailingAnchor),
            pdfView.bottomAnchor.constraint(equalTo: bottomAnchor),

            spinner.centerXAnchor.constraint(equalTo: centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor),

            errorLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            errorLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            errorLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @objc private func handleDoubleTap(_ gr: UITapGestureRecognizer) {
        let fit = pdfView.scaleFactorForSizeToFit
        let zoomedIn = pdfView.scaleFactor > fit * 1.01
        UIView.animate(withDuration: 0.25) { [weak self] in
            guard let self = self else { return }
            self.pdfView.scaleFactor = zoomedIn ? fit : min(fit * 2.0, self.pdfView.maxScaleFactor)
        }
    }

    private func registerObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(pageDidChange),
            name: .PDFViewPageChanged,
            object: pdfView
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    // MARK: - Loading

    func load() {
        if sourceURL.isFileURL {
            openLocal(sourceURL)
            return
        }
        var req = URLRequest(url: sourceURL)
        requestHeaders.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        let task = URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if let error = error {
                    self.showError(error.localizedDescription)
                    return
                }
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    self.showError("HTTP \(http.statusCode) loading PDF")
                    return
                }
                guard let data = data, !data.isEmpty else {
                    self.showError("Empty PDF response")
                    return
                }
                let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent("sw-daily-pdf-\(UUID().uuidString).pdf")
                do {
                    try data.write(to: tmp, options: .atomic)
                    self.tmpFileURL = tmp
                    self.openLocal(tmp)
                } catch {
                    self.showError(error.localizedDescription)
                }
            }
        }
        self.downloadTask = task
        task.resume()
    }

    private func openLocal(_ url: URL) {
        guard let doc = PDFDocument(url: url) else {
            showError("Unable to parse PDF")
            return
        }
        self.document = doc
        self.totalPages = doc.pageCount
        self.pdfView.document = doc
        self.spinner.stopAnimating()
        self.errorLabel.isHidden = true

        if let page = doc.page(at: 0) {
            pdfView.go(to: page)
        }
        currentPage = 1
        currentPageEnteredAt = Date()
        startEmitTimer()

        // Emit initial page-change so the caller knows total pages.
        onPageChanged?(currentPage, totalPages)
        onDocumentLoaded?(doc)
    }

    private func showError(_ message: String) {
        spinner.stopAnimating()
        errorLabel.text = message
        errorLabel.isHidden = false
        onLoadError?(message)
    }

    // MARK: - Page change

    @objc private func pageDidChange() {
        guard let doc = document, let page = pdfView.currentPage else { return }
        let newIndex = doc.index(for: page) + 1
        guard newIndex != currentPage else { return }
        flushCurrentPageDwell()
        currentPage = newIndex
        currentPageEnteredAt = Date()
        onPageChanged?(currentPage, totalPages)
    }

    // MARK: - Dwell

    private func flushCurrentPageDwell() {
        guard let start = currentPageEnteredAt else { return }
        let now = Date()
        let deltaMs = Int(now.timeIntervalSince(start) * 1000)
        guard deltaMs > 0 else { return }
        var stat = pageStats[currentPage] ?? PageStat()
        stat.cumulativeMs += deltaMs
        stat.lastDwellMs = deltaMs
        if stat.cumulativeMs >= minDwellMs { stat.viewed = true }
        pageStats[currentPage] = stat
        currentPageEnteredAt = now
    }

    // MARK: - Emit timer

    private func startEmitTimer() {
        guard emitIntervalMs > 0 else { return }
        emitTimer?.invalidate()
        let interval = TimeInterval(emitIntervalMs) / 1000.0
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.flushCurrentPageDwell()
            self.onTrackingUpdate?(self.snapshot(isFinal: false))
        }
        RunLoop.main.add(timer, forMode: .common)
        self.emitTimer = timer
    }

    // MARK: - Background / foreground

    @objc private func appDidEnterBackground() {
        flushCurrentPageDwell()
        currentPageEnteredAt = nil
        isPausedForBackground = true
    }

    @objc private func appWillEnterForeground() {
        if isPausedForBackground {
            isPausedForBackground = false
            if document != nil {
                currentPageEnteredAt = Date()
            }
        }
    }

    // MARK: - Snapshot

    func snapshot(isFinal: Bool) -> [String: Any] {
        let sortedPages = pageStats.keys.sorted()
        let entries: [[String: Any]] = sortedPages.map { pageNumber in
            let s = pageStats[pageNumber] ?? PageStat()
            return [
                "pageNumber": pageNumber,
                "timeSpentMs": s.cumulativeMs,
                "dwellMs": s.lastDwellMs,
                "viewed": s.viewed
            ]
        }
        let totalMs = pageStats.values.reduce(0) { $0 + $1.cumulativeMs }
        let viewedCount = pageStats.values.filter { $0.viewed }.count
        let progress: Double
        if totalPages > 0 {
            progress = (Double(viewedCount) / Double(totalPages)) * 100.0
        } else {
            progress = 0
        }
        return [
            "totalTimeSpentMs": totalMs,
            "totalPages": totalPages,
            "currentPage": currentPage,
            "pagesViewed": viewedCount,
            "progressPercentage": progress,
            "pageTimeEntries": entries,
            "isFinal": isFinal
        ]
    }

    // MARK: - Finalization

    /// Call when the PDF is being torn down (e.g. call ends) to flush final
    /// dwell and emit one last tracking snapshot with `isFinal: true`.
    func finalizeTracking() {
        guard !didFinalize else { return }
        didFinalize = true
        flushCurrentPageDwell()
        DispatchQueue.main.async { [weak emitTimer] in
            emitTimer?.invalidate()
        }
        emitTimer = nil
        onTrackingUpdate?(snapshot(isFinal: true))
    }
}
