import AppKit

private let rowHeight: CGFloat = 34
private let baseThumbnailSize = CGSize(width: 220, height: 182)
private let baseThumbnailSpacing: CGFloat = 10
private let thumbnailFooterHeight: CGFloat = 36
private let thumbnailFooterSpacing: CGFloat = 8

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
    private let captureQueue = DispatchQueue(label: "com.junwen.TabFlow.thumbnail-capture", qos: .userInitiated)
    private var cache: [WindowKey: NSImage] = [:]

    func cachedImage(for window: SwitchableWindow) -> NSImage? {
        cache[window.key]
    }

    func loadImage(for window: SwitchableWindow, completion: @escaping (NSImage?) -> Void) {
        if let image = cache[window.key] {
            completion(image)
            return
        }

        captureQueue.async { [weak self] in
            let cgImage = CGWindowListCreateImage(
                .null,
                .optionIncludingWindow,
                window.windowID,
                [.boundsIgnoreFraming, .nominalResolution]
            )
            DispatchQueue.main.async {
                guard let self else { return }
                let image = cgImage.map {
                    self.scaledImage(
                        NSImage(cgImage: $0, size: .zero),
                        maximumSize: CGSize(width: 440, height: 272)
                    )
                }
                if let image {
                    self.cache[window.key] = image
                }
                completion(image)
            }
        }
    }

    func retain(windows: [SwitchableWindow]) {
        let validKeys = Set(windows.map(\.key))
        cache = cache.filter { validKeys.contains($0.key) }
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
}

private final class WindowThumbnailView: NSView {
    private let thumbnailView = NSImageView()
    private let placeholderIconView = NSImageView()
    private let titleField = NSTextField(labelWithString: "")
    private let selectionBorderWidth: CGFloat

    init(window: SwitchableWindow, thumbnail: NSImage?, size: CGSize) {
        let scale = size.width / baseThumbnailSize.width
        selectionBorderWidth = max(1.5, 3 * scale)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = max(4, 8 * scale)
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        translatesAutoresizingMaskIntoConstraints = false

        let previewContainer = NSView()
        previewContainer.wantsLayer = true
        previewContainer.layer?.cornerRadius = max(3, 5 * scale)
        previewContainer.layer?.masksToBounds = true
        previewContainer.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.82).cgColor
        previewContainer.translatesAutoresizingMaskIntoConstraints = false

        thumbnailView.imageScaling = .scaleProportionallyUpOrDown
        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.addSubview(thumbnailView)

        placeholderIconView.image = window.application.icon
        placeholderIconView.imageScaling = .scaleProportionallyUpOrDown
        placeholderIconView.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.addSubview(placeholderIconView)

        let iconView = NSImageView()
        iconView.image = window.application.icon
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false

        titleField.stringValue = window.title.isEmpty
            ? (window.application.localizedName ?? "Unknown")
            : window.title
        titleField.lineBreakMode = .byTruncatingTail
        titleField.font = NSFont.systemFont(ofSize: max(9, 12 * scale), weight: .medium)
        titleField.translatesAutoresizingMaskIntoConstraints = false

        addSubview(previewContainer)
        addSubview(iconView)
        addSubview(titleField)

        let padding = max(4, 7 * scale)
        let iconSize = max(14, 20 * scale)
        let placeholderSize = max(36, 64 * scale)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: size.width),
            heightAnchor.constraint(equalToConstant: size.height),
            previewContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padding),
            previewContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padding),
            previewContainer.topAnchor.constraint(equalTo: topAnchor, constant: padding),
            previewContainer.heightAnchor.constraint(equalToConstant: 136 * scale),
            thumbnailView.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 3),
            thumbnailView.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -3),
            thumbnailView.topAnchor.constraint(equalTo: previewContainer.topAnchor, constant: 3),
            thumbnailView.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor, constant: -3),
            placeholderIconView.centerXAnchor.constraint(equalTo: previewContainer.centerXAnchor),
            placeholderIconView.centerYAnchor.constraint(equalTo: previewContainer.centerYAnchor),
            placeholderIconView.widthAnchor.constraint(equalToConstant: placeholderSize),
            placeholderIconView.heightAnchor.constraint(equalToConstant: placeholderSize),
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: max(6, 10 * scale)),
            iconView.topAnchor.constraint(equalTo: previewContainer.bottomAnchor, constant: max(4, 9 * scale)),
            iconView.widthAnchor.constraint(equalToConstant: iconSize),
            iconView.heightAnchor.constraint(equalToConstant: iconSize),
            titleField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: max(4, 7 * scale)),
            titleField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -max(6, 10 * scale)),
            titleField.centerYAnchor.constraint(equalTo: iconView.centerYAnchor)
        ])
        setThumbnail(thumbnail)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func setThumbnail(_ image: NSImage?) {
        thumbnailView.image = image
        thumbnailView.isHidden = image == nil
        placeholderIconView.isHidden = image != nil
    }

    func setSelected(_ selected: Bool) {
        layer?.borderWidth = selected ? selectionBorderWidth : 0
        layer?.borderColor = selected ? NSColor.controlAccentColor.cgColor : NSColor.clear.cgColor
        layer?.backgroundColor = selected
            ? NSColor.controlAccentColor.withAlphaComponent(0.18).cgColor
            : NSColor.controlBackgroundColor.cgColor
    }
}

final class SwitcherPanelController {
    private let panel: SwitcherPanel
    private let backgroundView = NSView()
    private let thumbnailProvider = ThumbnailProvider()
    private let selectedTitleField = NSTextField(labelWithString: "")
    private var layoutView: NSView?
    private var windows: [SwitchableWindow] = []
    private var itemViews: [Int: NSView] = [:]
    private var visibleRange = 0..<0
    private var selectedIndex = 0
    private var displayMode: SwitcherDisplayMode = .list
    private var thumbnailColumns = 1
    private var thumbnailSize = baseThumbnailSize
    private var thumbnailSpacing = baseThumbnailSpacing

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

        let visibleFrame = screen.visibleFrame
        let size: CGSize
        switch displayMode {
        case .list:
            visibleRange = listRangeToDisplay(selectedIndex: selectedIndex)
            size = listPanelSize(in: visibleFrame)
        case .thumbnails:
            visibleRange = 0..<windows.count
            configureThumbnailGrid(windowCount: windows.count, in: visibleFrame)
            size = thumbnailPanelSize(windowCount: windows.count)
            thumbnailProvider.retain(windows: windows)
        }

        rebuildLayout()
        let origin = CGPoint(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.midY - size.height / 2
        )
        panel.setFrame(CGRect(origin: origin, size: size), display: true)
        backgroundView.layoutSubtreeIfNeeded()
        panel.orderFrontRegardless()

        if displayMode == .thumbnails {
            loadThumbnails()
        }
    }

    func select(index: Int) {
        guard windows.indices.contains(index) else { return }
        let previousIndex = selectedIndex
        selectedIndex = index

        if displayMode == .thumbnails {
            updateSelectedTitle()
        }
        if displayMode == .list {
            let newRange = listRangeToDisplay(selectedIndex: index)
            if newRange != visibleRange {
                visibleRange = newRange
                rebuildLayout()
                return
            }
        }
        setSelected(false, at: previousIndex)
        setSelected(true, at: selectedIndex)
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
        panel.contentView = backgroundView
    }

    private func listPanelSize(in visibleFrame: CGRect) -> CGSize {
        let visibleCount = max(1, visibleRange.count)
        let rowsHeight = CGFloat(visibleCount) * rowHeight
        let spacingHeight = CGFloat(max(0, visibleCount - 1))
        let titleFont = NSFont.systemFont(ofSize: 13)
        let longestTitleWidth = windows
            .map { ($0.displayTitle as NSString).size(withAttributes: [.font: titleFont]).width }
            .max() ?? 0
        let width = min(visibleFrame.width * 0.85, max(560, longestTitleWidth + 80))
        return CGSize(width: width, height: rowsHeight + spacingHeight + 20)
    }

    private func configureThumbnailGrid(windowCount: Int, in visibleFrame: CGRect) {
        let availableWidth = visibleFrame.width * 0.9 - 20
        let availableHeight = visibleFrame.height * 0.85 - 20 - thumbnailFooterHeight - thumbnailFooterSpacing
        var scale: CGFloat = 1

        for _ in 0..<4 {
            let width = baseThumbnailSize.width * scale
            let height = baseThumbnailSize.height * scale
            let spacing = baseThumbnailSpacing * scale
            let columns = max(1, min(windowCount, Int((availableWidth + spacing) / (width + spacing))))
            let rows = Int(ceil(Double(windowCount) / Double(columns)))
            let requiredHeight = CGFloat(rows) * height + CGFloat(max(0, rows - 1)) * spacing
            if requiredHeight <= availableHeight {
                thumbnailColumns = columns
                thumbnailSize = CGSize(width: width, height: height)
                thumbnailSpacing = spacing
                return
            }
            scale *= availableHeight / requiredHeight
        }

        thumbnailSize = CGSize(width: baseThumbnailSize.width * scale, height: baseThumbnailSize.height * scale)
        thumbnailSpacing = baseThumbnailSpacing * scale
        thumbnailColumns = max(
            1,
            min(windowCount, Int((availableWidth + thumbnailSpacing) / (thumbnailSize.width + thumbnailSpacing)))
        )
    }

    private func thumbnailPanelSize(windowCount: Int) -> CGSize {
        let columns = min(thumbnailColumns, windowCount)
        let rows = Int(ceil(Double(windowCount) / Double(thumbnailColumns)))
        let width = CGFloat(columns) * thumbnailSize.width + CGFloat(max(0, columns - 1)) * thumbnailSpacing + 20
        let gridHeight = CGFloat(rows) * thumbnailSize.height + CGFloat(max(0, rows - 1)) * thumbnailSpacing
        let height = gridHeight + thumbnailFooterSpacing + thumbnailFooterHeight + 20
        return CGSize(width: width, height: height)
    }

    private func listRangeToDisplay(selectedIndex: Int) -> Range<Int> {
        guard !windows.isEmpty else { return 0..<0 }
        let visibleCount = min(14, windows.count)
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

    private func rebuildLayout() {
        layoutView?.removeFromSuperview()
        itemViews = [:]

        let newLayout: NSView
        switch displayMode {
        case .list:
            newLayout = buildListLayout()
        case .thumbnails:
            newLayout = buildThumbnailGrid()
        }

        newLayout.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(newLayout)
        NSLayoutConstraint.activate([
            newLayout.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor, constant: 10),
            newLayout.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor, constant: -10),
            newLayout.topAnchor.constraint(equalTo: backgroundView.topAnchor, constant: 10),
            newLayout.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor, constant: -10)
        ])
        layoutView = newLayout
    }

    private func buildListLayout() -> NSView {
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.distribution = .fill
        stackView.spacing = 1

        for index in visibleRange {
            let row = WindowRowView(window: windows[index])
            row.setSelected(index == selectedIndex)
            stackView.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
            itemViews[index] = row
        }
        return stackView
    }

    private func buildThumbnailGrid() -> NSView {
        var rows: [[NSView]] = []
        var row: [NSView] = []

        for index in windows.indices {
            let card = WindowThumbnailView(
                window: windows[index],
                thumbnail: thumbnailProvider.cachedImage(for: windows[index]),
                size: thumbnailSize
            )
            card.setSelected(index == selectedIndex)
            row.append(card)
            itemViews[index] = card

            if row.count == thumbnailColumns {
                rows.append(row)
                row = []
            }
        }

        if !row.isEmpty {
            while row.count < thumbnailColumns {
                let spacer = NSView()
                spacer.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    spacer.widthAnchor.constraint(equalToConstant: thumbnailSize.width),
                    spacer.heightAnchor.constraint(equalToConstant: thumbnailSize.height)
                ])
                row.append(spacer)
            }
            rows.append(row)
        }

        let gridView = NSGridView(views: rows)
        gridView.columnSpacing = thumbnailSpacing
        gridView.rowSpacing = thumbnailSpacing
        gridView.xPlacement = .fill
        gridView.yPlacement = .fill

        selectedTitleField.alignment = .center
        selectedTitleField.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        selectedTitleField.lineBreakMode = .byWordWrapping
        selectedTitleField.maximumNumberOfLines = 2
        updateSelectedTitle()

        let container = NSStackView()
        container.orientation = .vertical
        container.alignment = .centerX
        container.distribution = .fill
        container.spacing = thumbnailFooterSpacing
        container.addArrangedSubview(gridView)
        container.addArrangedSubview(selectedTitleField)
        selectedTitleField.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true
        selectedTitleField.heightAnchor.constraint(equalToConstant: thumbnailFooterHeight).isActive = true
        return container
    }

    private func updateSelectedTitle() {
        guard windows.indices.contains(selectedIndex) else {
            selectedTitleField.stringValue = ""
            return
        }
        selectedTitleField.stringValue = windows[selectedIndex].displayTitle
    }

    private func loadThumbnails() {
        for index in windows.indices {
            guard let card = itemViews[index] as? WindowThumbnailView else { continue }
            thumbnailProvider.loadImage(for: windows[index]) { [weak card] image in
                card?.setThumbnail(image)
            }
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
