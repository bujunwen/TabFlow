import AppKit

private let rowHeight: CGFloat = 34
private let thumbnailWidth: CGFloat = 220
private let thumbnailHeight: CGFloat = 182
private let thumbnailSpacing: CGFloat = 10

private final class SwitcherPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class WindowRowView: NSView {
    private let iconView = NSImageView()
    private let titleField = NSTextField(labelWithString: "")

    init(window: SwitchableWindow) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 5
        translatesAutoresizingMaskIntoConstraints = false

        iconView.image = window.application.icon
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false

        titleField.stringValue = window.displayTitle
        titleField.lineBreakMode = .byTruncatingTail
        titleField.font = NSFont.systemFont(ofSize: 13)
        titleField.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(titleField)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: rowHeight),
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
            titleField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            titleField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            titleField.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func setSelected(_ selected: Bool) {
        layer?.backgroundColor = selected ? NSColor.controlAccentColor.cgColor : NSColor.clear.cgColor
        titleField.textColor = selected ? NSColor.selectedMenuItemTextColor : NSColor.labelColor
    }
}

private final class ThumbnailProvider {
    private var cache: [WindowKey: NSImage] = [:]

    func image(for window: SwitchableWindow) -> NSImage? {
        if let image = cache[window.key] {
            return image
        }
        guard let windowID = window.windowID,
              let cgImage = CGWindowListCreateImage(
                .null,
                .optionIncludingWindow,
                windowID,
                [.boundsIgnoreFraming, .nominalResolution]
              ) else {
            return nil
        }
        let source = NSImage(cgImage: cgImage, size: .zero)
        let image = scaledImage(source, maximumSize: CGSize(width: 440, height: 272))
        cache[window.key] = image
        return image
    }

    private func scaledImage(_ source: NSImage, maximumSize: CGSize) -> NSImage {
        let scale = min(maximumSize.width / source.size.width, maximumSize.height / source.size.height, 1)
        guard scale < 1 else { return source }
        let size = CGSize(width: source.size.width * scale, height: source.size.height * scale)
        let result = NSImage(size: size)
        result.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        source.draw(in: CGRect(origin: .zero, size: size))
        result.unlockFocus()
        return result
    }

    func retain(windows: [SwitchableWindow]) {
        let validKeys = Set(windows.map(\.key))
        cache = cache.filter { validKeys.contains($0.key) }
    }
}

private final class WindowThumbnailView: NSView {
    private let titleField = NSTextField(labelWithString: "")

    init(window: SwitchableWindow, thumbnail: NSImage?) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        translatesAutoresizingMaskIntoConstraints = false

        let previewContainer = NSView()
        previewContainer.wantsLayer = true
        previewContainer.layer?.cornerRadius = 5
        previewContainer.layer?.masksToBounds = true
        previewContainer.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.82).cgColor
        previewContainer.translatesAutoresizingMaskIntoConstraints = false

        let previewView = NSImageView()
        previewView.image = thumbnail ?? window.application.icon
        previewView.imageScaling = .scaleProportionallyUpOrDown
        previewView.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.addSubview(previewView)

        let iconView = NSImageView()
        iconView.image = window.application.icon
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false

        titleField.stringValue = window.displayTitle
        titleField.lineBreakMode = .byTruncatingTail
        titleField.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleField.translatesAutoresizingMaskIntoConstraints = false

        addSubview(previewContainer)
        addSubview(iconView)
        addSubview(titleField)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: thumbnailWidth),
            heightAnchor.constraint(equalToConstant: thumbnailHeight),
            previewContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 7),
            previewContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -7),
            previewContainer.topAnchor.constraint(equalTo: topAnchor, constant: 7),
            previewContainer.heightAnchor.constraint(equalToConstant: 136),
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            iconView.topAnchor.constraint(equalTo: previewContainer.bottomAnchor, constant: 9),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
            titleField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 7),
            titleField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            titleField.centerYAnchor.constraint(equalTo: iconView.centerYAnchor)
        ])

        if thumbnail == nil {
            NSLayoutConstraint.activate([
                previewView.centerXAnchor.constraint(equalTo: previewContainer.centerXAnchor),
                previewView.centerYAnchor.constraint(equalTo: previewContainer.centerYAnchor),
                previewView.widthAnchor.constraint(equalToConstant: 64),
                previewView.heightAnchor.constraint(equalToConstant: 64)
            ])
        } else {
            NSLayoutConstraint.activate([
                previewView.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 4),
                previewView.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -4),
                previewView.topAnchor.constraint(equalTo: previewContainer.topAnchor, constant: 4),
                previewView.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor, constant: -4)
            ])
        }
    }

    required init?(coder: NSCoder) {
        nil
    }

    func setSelected(_ selected: Bool) {
        layer?.borderWidth = selected ? 3 : 0
        layer?.borderColor = selected ? NSColor.controlAccentColor.cgColor : NSColor.clear.cgColor
        layer?.backgroundColor = selected
            ? NSColor.controlAccentColor.withAlphaComponent(0.18).cgColor
            : NSColor.controlBackgroundColor.cgColor
    }
}

final class SwitcherPanelController {
    private let panel: SwitcherPanel
    private let backgroundView = NSView()
    private let stackView = NSStackView()
    private let thumbnailProvider = ThumbnailProvider()
    private var windows: [SwitchableWindow] = []
    private var itemViews: [Int: NSView] = [:]
    private var visibleRange = 0..<0
    private var selectedIndex = 0
    private var displayMode: SwitcherDisplayMode = .list
    private var visibleCapacity = 14

    init() {
        panel = SwitcherPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        configurePanel()
    }

    var isVisible: Bool { panel.isVisible }

    func show(windows: [SwitchableWindow], selectedIndex: Int, on screen: NSScreen) {
        self.windows = windows
        self.selectedIndex = selectedIndex
        displayMode = SwitcherDisplayMode.selected
        visibleRange = 0..<0

        let visibleFrame = screen.visibleFrame
        if displayMode == .thumbnails {
            let availableWidth = visibleFrame.width * 0.9 - 20
            visibleCapacity = min(7, max(1, Int((availableWidth + thumbnailSpacing) / (thumbnailWidth + thumbnailSpacing))))
            thumbnailProvider.retain(windows: windows)
        } else {
            visibleCapacity = 14
        }

        visibleRange = rangeToDisplay(selectedIndex: selectedIndex)
        rebuildItems()

        let size: CGSize
        switch displayMode {
        case .list:
            let visibleCount = max(1, visibleRange.count)
            let rowsHeight = CGFloat(visibleCount) * rowHeight
            let spacingHeight = CGFloat(max(0, visibleCount - 1))
            let titleFont = NSFont.systemFont(ofSize: 13)
            let longestTitleWidth = windows
                .map { ($0.displayTitle as NSString).size(withAttributes: [.font: titleFont]).width }
                .max() ?? 0
            let panelWidth = min(visibleFrame.width * 0.85, max(560, longestTitleWidth + 80))
            size = CGSize(width: panelWidth, height: rowsHeight + spacingHeight + 20)
        case .thumbnails:
            let count = max(1, visibleRange.count)
            let itemsWidth = CGFloat(count) * thumbnailWidth
            let spacingWidth = CGFloat(max(0, count - 1)) * thumbnailSpacing
            size = CGSize(width: itemsWidth + spacingWidth + 20, height: thumbnailHeight + 20)
        }

        let origin = CGPoint(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.midY - size.height / 2
        )
        panel.setFrame(CGRect(origin: origin, size: size), display: true)
        backgroundView.layoutSubtreeIfNeeded()
        panel.orderFrontRegardless()
    }

    func select(index: Int) {
        guard windows.indices.contains(index) else { return }
        let previousIndex = selectedIndex
        selectedIndex = index
        let newRange = rangeToDisplay(selectedIndex: index)

        if newRange != visibleRange {
            visibleRange = newRange
            rebuildItems()
        } else {
            setSelected(false, at: previousIndex)
            setSelected(true, at: selectedIndex)
        }
    }

    func hide() {
        panel.orderOut(nil)
        windows = []
        itemViews = [:]
        visibleRange = 0..<0
    }

    private func configurePanel() {
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.transient, .moveToActiveSpace, .fullScreenAuxiliary]

        backgroundView.wantsLayer = true
        backgroundView.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.97).cgColor
        backgroundView.layer?.cornerRadius = 10
        backgroundView.layer?.masksToBounds = true

        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false

        backgroundView.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor, constant: 10),
            stackView.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor, constant: -10),
            stackView.topAnchor.constraint(equalTo: backgroundView.topAnchor, constant: 10),
            stackView.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor, constant: -10)
        ])
        panel.contentView = backgroundView
    }

    private func rangeToDisplay(selectedIndex: Int) -> Range<Int> {
        guard !windows.isEmpty else { return 0..<0 }
        let visibleCount = min(visibleCapacity, windows.count)
        if windows.count <= visibleCount {
            return 0..<windows.count
        }
        if visibleRange.contains(selectedIndex) && visibleRange.count == visibleCount {
            return visibleRange
        }
        let maximumStart = windows.count - visibleCount
        let start = min(maximumStart, max(0, selectedIndex - visibleCount + 1))
        return start..<(start + visibleCount)
    }

    private func rebuildItems() {
        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        itemViews = [:]
        stackView.orientation = displayMode == .list ? .vertical : .horizontal
        stackView.alignment = displayMode == .list ? .leading : .centerY
        stackView.spacing = displayMode == .list ? 1 : thumbnailSpacing

        for index in visibleRange {
            let item: NSView
            switch displayMode {
            case .list:
                let row = WindowRowView(window: windows[index])
                row.setSelected(index == selectedIndex)
                row.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
                item = row
            case .thumbnails:
                let card = WindowThumbnailView(
                    window: windows[index],
                    thumbnail: thumbnailProvider.image(for: windows[index])
                )
                card.setSelected(index == selectedIndex)
                item = card
            }
            stackView.addArrangedSubview(item)
            itemViews[index] = item
        }
    }

    private func setSelected(_ selected: Bool, at index: Int) {
        if let row = itemViews[index] as? WindowRowView {
            row.setSelected(selected)
        } else if let thumbnail = itemViews[index] as? WindowThumbnailView {
            thumbnail.setSelected(selected)
        }
    }
}
