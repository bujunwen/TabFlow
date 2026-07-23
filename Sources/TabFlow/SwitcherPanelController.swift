import AppKit

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
            heightAnchor.constraint(equalToConstant: 34),
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

final class SwitcherPanelController {
    private let panel: SwitcherPanel
    private let backgroundView = NSView()
    private let stackView = NSStackView()
    private var windows: [SwitchableWindow] = []
    private var rowViews: [Int: WindowRowView] = [:]
    private var visibleRange = 0..<0
    private var selectedIndex = 0

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
        visibleRange = rangeToDisplay(selectedIndex: selectedIndex)
        rebuildRows()

        let visibleCount = max(1, visibleRange.count)
        let rowsHeight = CGFloat(visibleCount) * 34
        let spacingHeight = CGFloat(max(0, visibleCount - 1))
        let contentHeight = rowsHeight + spacingHeight + 20

        let titleFont = NSFont.systemFont(ofSize: 13)
        let longestTitleWidth = windows
            .map { ($0.displayTitle as NSString).size(withAttributes: [.font: titleFont]).width }
            .max() ?? 0
        let visibleFrame = screen.visibleFrame
        let maximumWidth = visibleFrame.width * 0.85
        let panelWidth = min(maximumWidth, max(560, longestTitleWidth + 80))
        let size = CGSize(width: panelWidth, height: contentHeight)
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
            rebuildRows()
        } else {
            rowViews[previousIndex]?.setSelected(false)
            rowViews[selectedIndex]?.setSelected(true)
        }
    }

    func hide() {
        panel.orderOut(nil)
        windows = []
        rowViews = [:]
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

        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.distribution = .fill
        stackView.spacing = 1
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

    private func rebuildRows() {
        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        rowViews = [:]

        for index in visibleRange {
            let row = WindowRowView(window: windows[index])
            row.setSelected(index == selectedIndex)
            stackView.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
            rowViews[index] = row
        }
    }
}
