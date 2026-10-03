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


// MARK: - Clean Floating Window Preview Card (Large Format, 5-Per-Row)

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
        super.init(frame: NSRect(x: 0, y: 0, width: 216, height: 168))

        wantsLayer = true
        setupThumbnailArea(thumbnail: thumbnail)
        setupTitle()
        setSelected(isSelected, animated: false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupThumbnailArea(thumbnail: CGImage?) {
        thumbnailContainer.frame = NSRect(x: 2, y: 2, width: 212, height: 136)
        thumbnailContainer.wantsLayer = true
        thumbnailContainer.layer?.cornerRadius = 10
        thumbnailContainer.layer?.masksToBounds = true
        thumbnailContainer.layer?.backgroundColor = NSColor(white: 0.12, alpha: 1.0).cgColor
        thumbnailContainer.layer?.borderWidth = 1.0
        thumbnailContainer.layer?.borderColor = NSColor(white: 0.32, alpha: 0.65).cgColor

        addSubview(thumbnailContainer)

        // Loading placeholder label (app name) centered cleanly inside the card box
        placeholderLabel.frame = NSRect(x: 10, y: 55, width: 192, height: 26)
        placeholderLabel.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        placeholderLabel.textColor = NSColor.white.withAlphaComponent(0.92)
        placeholderLabel.alignment = .center
        placeholderLabel.lineBreakMode = .byTruncatingTail
        placeholderLabel.stringValue = windowItem.appName
        thumbnailContainer.addSubview(placeholderLabel)

        if let thumb = thumbnail {
            applyThumbnail(thumb)
        }
    }

    private func setupTitle() {
        titleLabel.frame = NSRect(x: 2, y: 144, width: 212, height: 20)
        titleLabel.font = NSFont.systemFont(ofSize: 11.5, weight: .medium)
        titleLabel.textColor = NSColor.white.withAlphaComponent(0.85)
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byTruncatingMiddle
        titleLabel.stringValue = windowItem.title.isEmpty ? windowItem.appName : windowItem.title

        // Text shadow ensures readability over any background
        let textShadow = NSShadow()
        textShadow.shadowColor = NSColor.black.withAlphaComponent(0.95)
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
        let targetThumbnailAlpha: CGFloat = 1.0 // Fully opaque, never translucent
        let targetBorderWidth: CGFloat = selected ? 2.0 : 1.0
        let targetBorderColor = selected
            ? NSColor(white: 1.0, alpha: 0.70).cgColor
            : NSColor(white: 0.28, alpha: 0.60).cgColor
        let titleColor = selected ? NSColor.white : NSColor.white.withAlphaComponent(0.85)
        let titleFont = selected
            ? NSFont.systemFont(ofSize: 11.5, weight: .semibold)
            : NSFont.systemFont(ofSize: 11.5, weight: .medium)

        // Selected card gets a clean, natural dark drop shadow
        let cardShadow = NSShadow()
        if selected {
            cardShadow.shadowColor = NSColor.black.withAlphaComponent(0.65)
            cardShadow.shadowBlurRadius = 14
            cardShadow.shadowOffset = NSSize(width: 0, height: -4)
        } else {
            cardShadow.shadowColor = NSColor.black.withAlphaComponent(0.40)
            cardShadow.shadowBlurRadius = 10
            cardShadow.shadowOffset = NSSize(width: 0, height: -3)
        }
        self.shadow = cardShadow

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

// MARK: - Flipped Container View for Multi-Row Grid Layout

final class FlippedContainerView: NSView {
    override var isFlipped: Bool { true }
}

// MARK: - Pure Floating Cards Strip with Spotlight-Styled Search Bar & Multi-Row Grid

public final class AppKitSwitcherView: NSView {
    private let windows: [WindowItem]
    private var selectedIndex: Int
    private var cardViews: [WindowCardView] = []
    private let scrollView = NSScrollView()
    private let cardsContainer = FlippedContainerView()

    // Spotlight-Style Search Bar Components (1:1 Native Spotlight match)
    private let searchBarContainer = FlippedContainerView()
    private let visualEffectView = NSVisualEffectView()
    private let contentStackView = NSStackView()
    private let searchImageView = NSImageView()
    private let searchQueryLabel = NSTextField(labelWithString: "")
    private let searchBadgeLabel = NSTextField(labelWithString: "")
    private(set) var isSearching: Bool = false
    private var totalGridWidth: CGFloat = 0

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
        // Spotlight rounded-rectangle container (14pt radius, zero drop shadow)
        searchBarContainer.wantsLayer = true
        searchBarContainer.layer?.backgroundColor = NSColor.clear.cgColor
        searchBarContainer.layer?.cornerRadius = 14
        searchBarContainer.layer?.masksToBounds = false

        // Native Hardware Frosted Glass (NSVisualEffectView) with subtle 85% opacity
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.alphaValue = 0.85
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 14
        visualEffectView.layer?.masksToBounds = true
        visualEffectView.layer?.borderWidth = 1.0
        visualEffectView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.16).cgColor
        searchBarContainer.addSubview(visualEffectView)

        // Perfect horizontal & vertical center alignment stack
        contentStackView.orientation = .horizontal
        contentStackView.alignment = .centerY
        contentStackView.spacing = 10
        contentStackView.distribution = .fill

        // Native SF Symbol Magnifying Glass
        let config = NSImage.SymbolConfiguration(pointSize: 16.5, weight: .regular)
        searchImageView.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search")?.withSymbolConfiguration(config)
        searchImageView.contentTintColor = NSColor(white: 0.55, alpha: 0.85)
        searchImageView.imageScaling = .scaleProportionallyDown
        searchImageView.setContentHuggingPriority(.required, for: .horizontal)
        contentStackView.addArrangedSubview(searchImageView)

        // Search text query / placeholder
        searchQueryLabel.font = NSFont.systemFont(ofSize: 16, weight: .regular)
        searchQueryLabel.textColor = NSColor(white: 0.55, alpha: 0.85)
        searchQueryLabel.stringValue = "Press S to Search"
        searchQueryLabel.lineBreakMode = .byTruncatingTail
        searchQueryLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        contentStackView.addArrangedSubview(searchQueryLabel)

        // Match count badge (shown only when actively searching)
        searchBadgeLabel.font = NSFont.systemFont(ofSize: 12.5, weight: .semibold)
        searchBadgeLabel.textColor = NSColor(white: 1.0, alpha: 0.80)
        searchBadgeLabel.stringValue = ""
        searchBadgeLabel.alignment = .right
        searchBadgeLabel.isHidden = true
        searchBadgeLabel.setContentHuggingPriority(.required, for: .horizontal)
        contentStackView.addArrangedSubview(searchBadgeLabel)

        searchBarContainer.addSubview(contentStackView)
        addSubview(searchBarContainer)
    }

    private func buildUI() {
        let cardWidth: CGFloat = 216
        let cardHeight: CGFloat = 168
        let cardSpacing: CGFloat = 16
        let rowSpacing: CGFloat = 16
        let horizontalPadding: CGFloat = 16

        let columns = min(max(windows.count, 1), 5)
        let rows = Int(ceil(Double(windows.count) / 5.0))

        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.horizontalScrollElasticity = .none
        scrollView.verticalScrollElasticity = .none
        addSubview(scrollView)

        self.totalGridWidth = horizontalPadding * 2 + CGFloat(columns) * cardWidth + CGFloat(max(0, columns - 1)) * cardSpacing
        let totalGridHeight = CGFloat(rows) * cardHeight + CGFloat(max(0, rows - 1)) * rowSpacing
        cardsContainer.frame = NSRect(x: 0, y: 0, width: totalGridWidth, height: totalGridHeight)
        scrollView.documentView = cardsContainer

        // Lay out cards in a 5-per-row grid
        for (index, window) in windows.enumerated() {
            let cachedThumb = WindowThumbnailCache.shared.cachedThumbnail(for: window.id)
            let card = WindowCardView(window: window, isSelected: index == selectedIndex, thumbnail: cachedThumb)

            let col = index % 5
            let row = index / 5
            let cardX = horizontalPadding + CGFloat(col) * (cardWidth + cardSpacing)
            let cardY = CGFloat(row) * (cardHeight + rowSpacing)

            card.frame = NSRect(x: cardX, y: cardY, width: cardWidth, height: cardHeight)
            card.onSelect = { [weak self] selectedWin in
                self?.onWindowClicked?(selectedWin)
            }
            cardsContainer.addSubview(card)
            cardViews.append(card)
        }

        // Pre-stream textures in priority order (selected window first)
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
        let barWidth: CGFloat = min(620, max(460, bounds.width - 48))
        let barHeight: CGFloat = 48
        searchBarContainer.frame = NSRect(x: (bounds.width - barWidth) / 2, y: 16, width: barWidth, height: barHeight)

        // Fit frosted glass view to container (14pt radius, zero drop shadow)
        visualEffectView.frame = searchBarContainer.bounds
        visualEffectView.layer?.cornerRadius = 14

        // Layout stack with exact horizontal padding and perfect vertical optical centering
        contentStackView.frame = NSRect(x: 18, y: 0, width: barWidth - 36, height: barHeight)

        // Spotlight search bar bottom is at y=64. Generous 30pt separation to cards.
        let scrollY: CGFloat = 94
        let scrollHeight = max(0, bounds.height - scrollY)
        let effectiveGridWidth = totalGridWidth > 0 ? totalGridWidth : bounds.width
        let scrollWidth = min(effectiveGridWidth, bounds.width)
        let scrollX = max(0, (bounds.width - scrollWidth) / 2)
        scrollView.frame = NSRect(x: scrollX, y: scrollY, width: scrollWidth, height: scrollHeight)
    }

    public func enterSearch(query: String, selectedIndex: Int, matchedIndices: [Int]) {
        self.isSearching = true
        visualEffectView.alphaValue = 1.0 // Fully opaque when selected
        visualEffectView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.70).cgColor
        visualEffectView.layer?.borderWidth = 1.25
        searchBadgeLabel.isHidden = false
        updateSearch(query: query, selectedIndex: selectedIndex, matchedIndices: matchedIndices)
    }

    public func updateSearch(query: String, selectedIndex: Int, matchedIndices: [Int]) {
        let hasMatches = !matchedIndices.isEmpty

        // Update search query text & cursor
        if query.isEmpty {
            searchQueryLabel.stringValue = "|"
            searchQueryLabel.textColor = .white
            searchBadgeLabel.stringValue = "\(windows.count) windows"
            searchBadgeLabel.textColor = NSColor(white: 1.0, alpha: 0.80)
            visualEffectView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.65).cgColor
            visualEffectView.layer?.borderWidth = 1.25
        } else {
            searchQueryLabel.stringValue = "\(query)|"
            searchQueryLabel.textColor = .white
            if hasMatches {
                searchBadgeLabel.stringValue = "\(matchedIndices.count) match\(matchedIndices.count == 1 ? "" : "es")"
                searchBadgeLabel.textColor = NSColor(white: 1.0, alpha: 0.80)
                visualEffectView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.65).cgColor
                visualEffectView.layer?.borderWidth = 1.25
            } else {
                searchBadgeLabel.stringValue = "No matches"
                searchBadgeLabel.textColor = NSColor.systemRed
                visualEffectView.layer?.borderColor = NSColor.systemRed.withAlphaComponent(0.85).cgColor
                visualEffectView.layer?.borderWidth = 1.25
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

        // Auto-scroll vertically if grid exceeds visible rows
        let cardHeight: CGFloat = 168
        let rowSpacing: CGFloat = 16
        let targetRow = newIndex / 5
        let visibleHeight = scrollView.bounds.height
        guard visibleHeight > 0 else { return }

        let targetY = max(0, min(CGFloat(targetRow) * (cardHeight + rowSpacing), cardsContainer.bounds.height - visibleHeight))

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.16
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.scrollView.contentView.animator().setBoundsOrigin(NSPoint(x: 0, y: targetY))
            }
        } else {
            scrollView.contentView.setBoundsOrigin(NSPoint(x: 0, y: targetY))
        }
    }

    public func teardown() {
        for card in cardViews {
            card.teardown()
        }
        cardViews.removeAll()
    }

    public func calculatePreferredSize() -> NSSize {
        let cardWidth: CGFloat = 216
        let cardHeight: CGFloat = 168
        let cardSpacing: CGFloat = 16
        let rowSpacing: CGFloat = 16
        let horizontalPadding: CGFloat = 16

        let columns = min(max(windows.count, 1), 5)
        let rows = min(max(Int(ceil(Double(windows.count) / 5.0)), 1), 2)

        let totalCardsWidth = horizontalPadding * 2 + CGFloat(columns) * cardWidth + CGFloat(max(0, columns - 1)) * cardSpacing
        let totalGridHeight = CGFloat(rows) * cardHeight + CGFloat(max(0, rows - 1)) * rowSpacing

        let topPadding: CGFloat = 16
        let searchBarHeight: CGFloat = 48
        let searchMarginBottom: CGFloat = 30
        let bottomPadding: CGFloat = 18
        let totalHeight = topPadding + searchBarHeight + searchMarginBottom + totalGridHeight + bottomPadding

        let minHUDWidth: CGFloat = 640
        return NSSize(width: max(totalCardsWidth, minHUDWidth), height: totalHeight)
    }
}
