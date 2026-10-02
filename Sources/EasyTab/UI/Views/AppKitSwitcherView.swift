import AppKit
import CoreGraphics
import QuartzCore

// MARK: - Legacy Window Capture Bridge

@_silgen_name("CGWindowListCreateImage")
func LegacyCGWindowListCreateImage(
    _ screenBounds: CGRect,
    _ listOption: CGWindowListOption,
    _ windowID: CGWindowID,
    _ imageOption: CGWindowImageOption
) -> CGImage?

// MARK: - Zero-Copy Hardware Window Thumbnail Cache

public final class WindowThumbnailCache: @unchecked Sendable {
    public static let shared = WindowThumbnailCache()
    private var cache = [CGWindowID: CGImage]()
    private let lock = NSLock()
    private let captureQueue = DispatchQueue(label: "com.easytab.capture", qos: .userInteractive)

    private init() {}

    public func cachedThumbnail(for windowID: CGWindowID) -> CGImage? {
        lock.lock()
        defer { lock.unlock() }
        return cache[windowID]
    }

    public func captureThumbnail(for windowID: CGWindowID, completion: @escaping @MainActor @Sendable (CGImage?) -> Void) {
        lock.lock()
        if let cached = cache[windowID] {
            lock.unlock()
            DispatchQueue.main.async {
                completion(cached)
            }
            return
        }
        lock.unlock()

        captureQueue.async {
            guard let cgImg = LegacyCGWindowListCreateImage(
                .null,
                .optionIncludingWindow,
                windowID,
                [.boundsIgnoreFraming, .nominalResolution]
            ) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            self.lock.lock()
            self.cache[windowID] = cgImg
            self.lock.unlock()

            DispatchQueue.main.async {
                completion(cgImg)
            }
        }
    }

    public func clear() {
        lock.lock()
        cache.removeAll(keepingCapacity: false)
        lock.unlock()
    }
}

// MARK: - Clean Floating Window Preview Card (Zero Outer Box)

final class WindowCardView: NSView {
    let windowItem: WindowItem
    private let thumbnailContainer = NSView()
    private let placeholderLabel = NSTextField(labelWithString: "")
    private let titleLabel = NSTextField(labelWithString: "")
    private var isTornDown: Bool = false

    var onSelect: ((WindowItem) -> Void)?

    override var isFlipped: Bool { true }

    init(window: WindowItem, isSelected: Bool, thumbnail: CGImage?) {
        self.windowItem = window
        super.init(frame: NSRect(x: 0, y: 0, width: 174, height: 136))

        wantsLayer = true
        setupThumbnailArea(thumbnail: thumbnail)
        setupTitle()
        setSelected(isSelected, animated: false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupThumbnailArea(thumbnail: CGImage?) {
        thumbnailContainer.frame = NSRect(x: 2, y: 2, width: 170, height: 105)
        thumbnailContainer.wantsLayer = true
        thumbnailContainer.layer?.cornerRadius = 10
        thumbnailContainer.layer?.masksToBounds = true
        thumbnailContainer.layer?.backgroundColor = NSColor(white: 0.12, alpha: 0.95).cgColor
        thumbnailContainer.layer?.borderWidth = 1.0
        thumbnailContainer.layer?.borderColor = NSColor(white: 0.30, alpha: 0.60).cgColor

        // Floating card drop shadow
        let dropShadow = NSShadow()
        dropShadow.shadowColor = NSColor.black.withAlphaComponent(0.50)
        dropShadow.shadowBlurRadius = 10
        dropShadow.shadowOffset = NSSize(width: 0, height: -4)
        self.shadow = dropShadow

        addSubview(thumbnailContainer)

        // Loading placeholder label (app name) while texture streams in
        placeholderLabel.frame = NSRect(x: 10, y: 40, width: 150, height: 24)
        placeholderLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        placeholderLabel.textColor = NSColor.white.withAlphaComponent(0.90)
        placeholderLabel.alignment = .center
        placeholderLabel.lineBreakMode = .byTruncatingTail
        placeholderLabel.stringValue = windowItem.appName
        thumbnailContainer.addSubview(placeholderLabel)

        if let thumb = thumbnail {
            applyThumbnail(thumb)
        }
    }

    private func setupTitle() {
        titleLabel.frame = NSRect(x: 2, y: 114, width: 170, height: 18)
        titleLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        titleLabel.textColor = NSColor.white.withAlphaComponent(0.85)
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.stringValue = windowItem.title.isEmpty ? windowItem.appName : windowItem.title

        // Text shadow ensures readability over any wallpaper or document
        let textShadow = NSShadow()
        textShadow.shadowColor = NSColor.black.withAlphaComponent(0.90)
        textShadow.shadowBlurRadius = 4
        textShadow.shadowOffset = NSSize(width: 0, height: -1)
        titleLabel.shadow = textShadow

        addSubview(titleLabel)
    }

    func applyThumbnail(_ thumb: CGImage) {
        guard !isTornDown else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        placeholderLabel.isHidden = true
        thumbnailContainer.layer?.contents = thumb
        thumbnailContainer.layer?.contentsGravity = .resizeAspectFill
        CATransaction.commit()
    }

    func setSelected(_ selected: Bool, animated: Bool = true) {
        let targetThumbnailAlpha: CGFloat = selected ? 1.0 : 0.78
        let targetBorderWidth: CGFloat = selected ? 2.5 : 1.0
        let targetBorderColor = selected
            ? NSColor.controlAccentColor.cgColor
            : NSColor(white: 0.30, alpha: 0.60).cgColor
        let titleColor = selected ? NSColor.white : NSColor.white.withAlphaComponent(0.85)
        let titleFont = selected
            ? NSFont.systemFont(ofSize: 11, weight: .semibold)
            : NSFont.systemFont(ofSize: 11, weight: .medium)

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                self.thumbnailContainer.animator().alphaValue = targetThumbnailAlpha
                self.titleLabel.textColor = titleColor
                self.titleLabel.font = titleFont
            }
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.12)
            thumbnailContainer.layer?.borderWidth = targetBorderWidth
            thumbnailContainer.layer?.borderColor = targetBorderColor
            CATransaction.commit()
        } else {
            thumbnailContainer.alphaValue = targetThumbnailAlpha
            thumbnailContainer.layer?.borderWidth = targetBorderWidth
            thumbnailContainer.layer?.borderColor = targetBorderColor
            titleLabel.textColor = titleColor
            titleLabel.font = titleFont
        }
    }

    func setDimmed(_ dimmed: Bool, animated: Bool = true) {
        let targetAlpha: CGFloat = dimmed ? 0.28 : 1.0
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                self.animator().alphaValue = targetAlpha
            }
        } else {
            self.alphaValue = targetAlpha
        }
    }

    func teardown() {
        isTornDown = true
        thumbnailContainer.layer?.contents = nil
    }

    override func mouseDown(with event: NSEvent) {
        onSelect?(windowItem)
    }
}

// MARK: - Pure Floating Cards Strip with Inline Search Bar

public final class AppKitSwitcherView: NSView {
    private let windows: [WindowItem]
    private var selectedIndex: Int
    private var cardViews: [WindowCardView] = []
    private let scrollView = NSScrollView()
    private let cardsContainer = NSView()

    // Search Bar Components
    private let searchBarContainer = NSView()
    private let searchIconLabel = NSTextField(labelWithString: "🔍")
    private let searchQueryLabel = NSTextField(labelWithString: "")
    private let searchBadgeLabel = NSTextField(labelWithString: "")
    private(set) var isSearching: Bool = false

    public var onWindowClicked: ((WindowItem) -> Void)?

    public override var isFlipped: Bool { true }

    public init(windows: [WindowItem], selectedIndex: Int) {
        self.windows = windows
        self.selectedIndex = selectedIndex
        super.init(frame: .zero)

        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        buildSearchBarUI()
        buildUI()
        updateSelection(selectedIndex, animated: false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildSearchBarUI() {
        searchBarContainer.wantsLayer = true
        searchBarContainer.layer?.cornerRadius = 16
        searchBarContainer.layer?.masksToBounds = true
        searchBarContainer.layer?.backgroundColor = NSColor(white: 0.14, alpha: 0.98).cgColor
        searchBarContainer.layer?.borderWidth = 1.5
        searchBarContainer.layer?.borderColor = NSColor.controlAccentColor.cgColor
        searchBarContainer.isHidden = true

        let dropShadow = NSShadow()
        dropShadow.shadowColor = NSColor.black.withAlphaComponent(0.40)
        dropShadow.shadowBlurRadius = 8
        dropShadow.shadowOffset = NSSize(width: 0, height: -2)
        searchBarContainer.shadow = dropShadow

        // Search icon
        searchIconLabel.font = NSFont.systemFont(ofSize: 13)
        searchIconLabel.alignment = .center
        searchBarContainer.addSubview(searchIconLabel)

        // Search text query
        searchQueryLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        searchQueryLabel.textColor = .white
        searchQueryLabel.lineBreakMode = .byTruncatingTail
        searchBarContainer.addSubview(searchQueryLabel)

        // Match count badge
        searchBadgeLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        searchBadgeLabel.textColor = NSColor.controlAccentColor
        searchBadgeLabel.alignment = .right
        searchBarContainer.addSubview(searchBadgeLabel)

        addSubview(searchBarContainer)
    }

    private func buildUI() {
        let cardSpacing: CGFloat = 14
        let cardWidth: CGFloat = 174
        let cardHeight: CGFloat = 136
        let horizontalPadding: CGFloat = 8

        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.horizontalScrollElasticity = .none
        scrollView.verticalScrollElasticity = .none
        addSubview(scrollView)

        let totalCardsWidth = horizontalPadding * 2 + CGFloat(windows.count) * cardWidth + CGFloat(max(0, windows.count - 1)) * cardSpacing
        cardsContainer.frame = NSRect(x: 0, y: 0, width: totalCardsWidth, height: cardHeight)
        scrollView.documentView = cardsContainer

        for (index, window) in windows.enumerated() {
            let cachedThumb = WindowThumbnailCache.shared.cachedThumbnail(for: window.id)
            let card = WindowCardView(window: window, isSelected: index == selectedIndex, thumbnail: cachedThumb)
            let cardX = horizontalPadding + CGFloat(index) * (cardWidth + cardSpacing)
            card.frame = NSRect(x: cardX, y: 0, width: cardWidth, height: cardHeight)
            card.onSelect = { [weak self] selectedWin in
                self?.onWindowClicked?(selectedWin)
            }
            cardsContainer.addSubview(card)
            cardViews.append(card)
        }

        var captureIndices = [selectedIndex]
        for i in 0..<windows.count {
            if i != selectedIndex {
                captureIndices.append(i)
            }
        }

        for i in captureIndices {
            let win = windows[i]
            if WindowThumbnailCache.shared.cachedThumbnail(for: win.id) == nil {
                let card = cardViews[i]
                WindowThumbnailCache.shared.captureThumbnail(for: win.id) { [weak card] capturedImg in
                    guard let capturedImg = capturedImg else { return }
                    card?.applyThumbnail(capturedImg)
                }
            }
        }
    }

    public override func layout() {
        super.layout()
        if isSearching {
            let barWidth: CGFloat = min(360, max(280, bounds.width - 48))
            searchBarContainer.frame = NSRect(x: (bounds.width - barWidth) / 2, y: 6, width: barWidth, height: 32)
            searchIconLabel.frame = NSRect(x: 10, y: 7, width: 18, height: 18)
            searchQueryLabel.frame = NSRect(x: 34, y: 7, width: barWidth - 120, height: 18)
            searchBadgeLabel.frame = NSRect(x: barWidth - 84, y: 7, width: 74, height: 18)

            scrollView.frame = NSRect(x: 0, y: 46, width: bounds.width, height: 136)
        } else {
            searchBarContainer.frame = .zero
            scrollView.frame = NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
        }
    }

    public func enterSearch(query: String, selectedIndex: Int, matchedIndices: [Int]) {
        self.isSearching = true
        self.searchBarContainer.isHidden = false
        needsLayout = true
        layoutSubtreeIfNeeded()
        updateSearch(query: query, selectedIndex: selectedIndex, matchedIndices: matchedIndices)
    }

    public func updateSearch(query: String, selectedIndex: Int, matchedIndices: [Int]) {
        let hasMatches = !matchedIndices.isEmpty

        // Update search query text & cursor
        if query.isEmpty {
            searchQueryLabel.stringValue = "Search open windows..."
            searchQueryLabel.textColor = NSColor.white.withAlphaComponent(0.45)
            searchBadgeLabel.stringValue = "\(windows.count) windows"
            searchBadgeLabel.textColor = NSColor.white.withAlphaComponent(0.55)
            searchBarContainer.layer?.borderColor = NSColor(white: 0.35, alpha: 0.8).cgColor
        } else {
            searchQueryLabel.stringValue = "\(query)|"
            searchQueryLabel.textColor = .white
            if hasMatches {
                searchBadgeLabel.stringValue = "\(matchedIndices.count) match\(matchedIndices.count == 1 ? "" : "es")"
                searchBadgeLabel.textColor = NSColor.controlAccentColor
                searchBarContainer.layer?.borderColor = NSColor.controlAccentColor.cgColor
            } else {
                searchBadgeLabel.stringValue = "No matches"
                searchBadgeLabel.textColor = NSColor.systemRed
                searchBarContainer.layer?.borderColor = NSColor.systemRed.withAlphaComponent(0.85).cgColor
            }
        }

        // Highlight matching cards and dim non-matching ones
        for (index, card) in cardViews.enumerated() {
            if query.isEmpty {
                card.setDimmed(false)
            } else {
                let isMatch = matchedIndices.contains(index)
                card.setDimmed(!isMatch)
            }
        }

        if selectedIndex >= 0 && selectedIndex < cardViews.count {
            updateSelection(selectedIndex, animated: true)
        }
    }

    public func updateSelection(_ newIndex: Int, animated: Bool = true) {
        guard newIndex >= 0 && newIndex < cardViews.count else { return }
        self.selectedIndex = newIndex

        for (index, card) in cardViews.enumerated() {
            card.setSelected(index == newIndex, animated: animated)
        }

        let targetCard = cardViews[newIndex]
        let cardFrame = targetCard.frame
        let visibleWidth = scrollView.bounds.width
        guard visibleWidth > 0 else { return }

        let targetX = max(0, min(cardFrame.midX - (visibleWidth / 2), cardsContainer.bounds.width - visibleWidth))

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.scrollView.contentView.animator().setBoundsOrigin(NSPoint(x: targetX, y: 0))
            }
        } else {
            scrollView.contentView.setBoundsOrigin(NSPoint(x: targetX, y: 0))
        }
    }

    public func teardown() {
        for card in cardViews {
            card.teardown()
        }
        cardViews.removeAll()
    }

    public func calculatePreferredSize(isSearching: Bool = false) -> NSSize {
        let cardWidth: CGFloat = 174
        let cardSpacing: CGFloat = 14
        let horizontalPadding: CGFloat = 8
        let totalCardsWidth = horizontalPadding * 2 + CGFloat(windows.count) * cardWidth + CGFloat(max(0, windows.count - 1)) * cardSpacing
        let preferredWidth = min(max(totalCardsWidth, 380), 1080)
        let preferredHeight: CGFloat = isSearching ? 188 : 144
        return NSSize(width: preferredWidth, height: preferredHeight)
    }
}
