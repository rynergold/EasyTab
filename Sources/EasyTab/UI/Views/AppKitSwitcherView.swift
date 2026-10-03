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

// MARK: - Physical Keyboard Keycap Badge View

final class KeycapBadgeView: NSView {
    private let label = NSTextField(labelWithString: "S")

    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 5
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.12).cgColor
        layer?.borderWidth = 1.0
        layer?.borderColor = NSColor(white: 1.0, alpha: 0.22).cgColor

        if let descriptor = NSFont.systemFont(ofSize: 11, weight: .bold).fontDescriptor.withDesign(.rounded),
           let roundedFont = NSFont(descriptor: descriptor, size: 11) {
            label.font = roundedFont
        } else {
            label.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        }
        label.textColor = NSColor.white.withAlphaComponent(0.92)
        label.alignment = .center
        addSubview(label)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        label.frame = NSRect(x: 0, y: (bounds.height - 15) / 2, width: bounds.width, height: 15)
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
        thumbnailContainer.layer?.backgroundColor = NSColor(white: 0.12, alpha: 0.95).cgColor
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
        let targetThumbnailAlpha: CGFloat = selected ? 1.0 : 0.78
        let targetBorderWidth: CGFloat = selected ? 2.5 : 1.0
        let targetBorderColor = selected
            ? NSColor.controlAccentColor.cgColor
            : NSColor(white: 0.32, alpha: 0.65).cgColor
        let titleColor = selected ? NSColor.white : NSColor.white.withAlphaComponent(0.85)
        let titleFont = selected
            ? NSFont.systemFont(ofSize: 11.5, weight: .semibold)
            : NSFont.systemFont(ofSize: 11.5, weight: .medium)

        // Selected card gets a subtle macOS accent glow halo
        let cardShadow = NSShadow()
        if selected {
            cardShadow.shadowColor = NSColor.controlAccentColor.withAlphaComponent(0.40)
            cardShadow.shadowBlurRadius = 18
            cardShadow.shadowOffset = NSSize(width: 0, height: -4)
        } else {
            cardShadow.shadowColor = NSColor.black.withAlphaComponent(0.55)
            cardShadow.shadowBlurRadius = 12
            cardShadow.shadowOffset = NSSize(width: 0, height: -4)
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

    // Spotlight-Style Search Bar Components
    private let searchBarContainer = NSView()
    private let searchImageView = NSImageView()
    private let searchQueryLabel = NSTextField(labelWithString: "")
    private let keycapView = KeycapBadgeView(frame: NSRect(x: 0, y: 0, width: 22, height: 22))
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
        // Spotlight pill container
        searchBarContainer.wantsLayer = true
        searchBarContainer.layer?.cornerRadius = 18 // Perfect 36pt pill capsule
        searchBarContainer.layer?.masksToBounds = true
        searchBarContainer.layer?.backgroundColor = NSColor(white: 0.14, alpha: 0.96).cgColor
        searchBarContainer.layer?.borderWidth = 1.0
        searchBarContainer.layer?.borderColor = NSColor(white: 0.30, alpha: 0.70).cgColor

        let dropShadow = NSShadow()
        dropShadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
        dropShadow.shadowBlurRadius = 12
        dropShadow.shadowOffset = NSSize(width: 0, height: -3)
        searchBarContainer.shadow = dropShadow

        // Native SF Symbol Magnifying Glass (0 KB external download)
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        searchImageView.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search")?.withSymbolConfiguration(config)
        searchImageView.contentTintColor = NSColor.white.withAlphaComponent(0.65)
        searchImageView.imageScaling = .scaleProportionallyDown
        searchBarContainer.addSubview(searchImageView)

        // Search text query / placeholder
        searchQueryLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        searchQueryLabel.textColor = NSColor.white.withAlphaComponent(0.48)
        searchQueryLabel.stringValue = "Search open windows..."
        searchQueryLabel.lineBreakMode = .byTruncatingTail
        searchBarContainer.addSubview(searchQueryLabel)

        // Clear [ S ] Keycap Badge
        searchBarContainer.addSubview(keycapView)

        // Match count badge (shown when actively searching)
        searchBadgeLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        searchBadgeLabel.textColor = NSColor.controlAccentColor
        searchBadgeLabel.stringValue = ""
        searchBadgeLabel.alignment = .right
        searchBadgeLabel.isHidden = true
        searchBarContainer.addSubview(searchBadgeLabel)

        addSubview(searchBarContainer)
    }

    private func buildUI() {
        let cardWidth: CGFloat = 216
        let cardHeight: CGFloat = 168
        let cardSpacing: CGFloat = 14
        let rowSpacing: CGFloat = 14
        let horizontalPadding: CGFloat = 12

        let columns = min(max(windows.count, 1), 5)
        let rows = Int(ceil(Double(windows.count) / 5.0))

        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.horizontalScrollElasticity = .none
        scrollView.verticalScrollElasticity = .none
        addSubview(scrollView)

        let totalGridWidth = horizontalPadding * 2 + CGFloat(columns) * cardWidth + CGFloat(max(0, columns - 1)) * cardSpacing
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
        let barWidth: CGFloat = min(360, max(300, bounds.width - 64))
        searchBarContainer.frame = NSRect(x: (bounds.width - barWidth) / 2, y: 8, width: barWidth, height: 36)
        searchImageView.frame = NSRect(x: 12, y: 10, width: 16, height: 16)
        searchQueryLabel.frame = NSRect(x: 36, y: 9, width: barWidth - 110, height: 18)
        keycapView.frame = NSRect(x: barWidth - 32, y: 7, width: 22, height: 22)
        searchBadgeLabel.frame = NSRect(x: barWidth - 95, y: 9, width: 85, height: 18)

        let scrollY: CGFloat = 56
        let scrollHeight = max(0, bounds.height - scrollY)
        scrollView.frame = NSRect(x: 0, y: scrollY, width: bounds.width, height: scrollHeight)
    }

    public func enterSearch(query: String, selectedIndex: Int, matchedIndices: [Int]) {
        self.isSearching = true
        searchBarContainer.layer?.borderColor = NSColor.controlAccentColor.cgColor
        searchBarContainer.layer?.borderWidth = 1.5
        keycapView.isHidden = true
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
            searchBadgeLabel.textColor = NSColor.controlAccentColor
            searchBarContainer.layer?.borderColor = NSColor.controlAccentColor.cgColor
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

        // Auto-scroll vertically if grid exceeds visible rows
        let cardHeight: CGFloat = 168
        let rowSpacing: CGFloat = 14
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
        let cardSpacing: CGFloat = 14
        let rowSpacing: CGFloat = 14
        let horizontalPadding: CGFloat = 12

        let columns = min(max(windows.count, 1), 5)
        let rows = min(max(Int(ceil(Double(windows.count) / 5.0)), 1), 2)

        let totalWidth = horizontalPadding * 2 + CGFloat(columns) * cardWidth + CGFloat(max(0, columns - 1)) * cardSpacing
        let totalGridHeight = CGFloat(rows) * cardHeight + CGFloat(max(0, rows - 1)) * rowSpacing

        let searchBarHeight: CGFloat = 36
        let searchMarginBottom: CGFloat = 16
        let topPadding: CGFloat = 8
        let bottomPadding: CGFloat = 12
        let totalHeight = topPadding + searchBarHeight + searchMarginBottom + totalGridHeight + bottomPadding

        return NSSize(width: max(totalWidth, 360), height: totalHeight)
    }
}
