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

        self.alphaValue = 1.0

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

    func teardown() {
        isTornDown = true
        thumbnailContainer.layer?.contents = nil
    }

    override func mouseDown(with event: NSEvent) {
        onSelect?(windowItem)
    }
}

// MARK: - Pure Floating Cards Strip (100% Transparent Container)

public final class AppKitSwitcherView: NSView {
    private let windows: [WindowItem]
    private var selectedIndex: Int
    private var cardViews: [WindowCardView] = []
    private let scrollView = NSScrollView()
    private let cardsContainer = NSView()

    public var onWindowClicked: ((WindowItem) -> Void)?

    public override var isFlipped: Bool { true }

    public init(windows: [WindowItem], selectedIndex: Int) {
        self.windows = windows
        self.selectedIndex = selectedIndex
        super.init(frame: .zero)

        // 100% transparent backdrop — zero darkened gray outer container!
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        buildUI()
        updateSelection(selectedIndex, animated: false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildUI() {
        let cardSpacing: CGFloat = 14
        let cardWidth: CGFloat = 174
        let cardHeight: CGFloat = 136
        let horizontalPadding: CGFloat = 8

        // Horizontal Scroll View
        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.horizontalScrollElasticity = .none
        scrollView.verticalScrollElasticity = .none
        addSubview(scrollView)

        let totalCardsWidth = horizontalPadding * 2 + CGFloat(windows.count) * cardWidth + CGFloat(max(0, windows.count - 1)) * cardSpacing
        cardsContainer.frame = NSRect(x: 0, y: 0, width: totalCardsWidth, height: cardHeight)
        scrollView.documentView = cardsContainer

        // Instantly build all floating cards
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

        // Asynchronously stream window previews in priority order (selected window first)
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
        scrollView.frame = bounds
    }

    public func updateSelection(_ newIndex: Int, animated: Bool = true) {
        guard newIndex >= 0 && newIndex < cardViews.count else { return }
        self.selectedIndex = newIndex

        for (index, card) in cardViews.enumerated() {
            card.setSelected(index == newIndex, animated: animated)
        }

        // Center selected card in scroll view
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

    public func calculatePreferredSize() -> NSSize {
        let cardWidth: CGFloat = 174
        let cardSpacing: CGFloat = 14
        let horizontalPadding: CGFloat = 8
        let totalCardsWidth = horizontalPadding * 2 + CGFloat(windows.count) * cardWidth + CGFloat(max(0, windows.count - 1)) * cardSpacing
        let preferredWidth = min(max(totalCardsWidth, 380), 1080)
        return NSSize(width: preferredWidth, height: 144)
    }
}
