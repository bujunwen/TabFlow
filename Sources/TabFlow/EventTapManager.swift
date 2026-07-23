import AppKit

private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let manager = Unmanaged<EventTapManager>.fromOpaque(refcon).takeUnretainedValue()
    return manager.handle(type: type, event: event)
}

final class EventTapManager {
    private let windowStore: WindowStore
    private let panelController: SwitcherPanelController
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var sessionWindows: [SwitchableWindow] = []
    private var selectedIndex = 0
    private var sessionActive = false

    init(windowStore: WindowStore, panelController: SwitcherPanelController) {
        self.windowStore = windowStore
        self.panelController = panelController
    }

    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue) |
            CGEventMask(1 << CGEventType.keyUp.rawValue) |
            CGEventMask(1 << CGEventType.flagsChanged.rawValue) |
            CGEventMask(1 << CGEventType.tapDisabledByTimeout.rawValue) |
            CGEventMask(1 << CGEventType.tapDisabledByUserInput.rawValue)

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: refcon
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        runLoopSource = source
        return true
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        cancelSession()
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let commandIsDown = event.flags.contains(.maskCommand)

        if type == .keyDown && keyCode == 48 && commandIsDown {
            if sessionActive {
                advanceSelection()
            } else {
                beginSession()
            }
            return nil
        }

        if type == .keyUp && keyCode == 48 && sessionActive {
            return nil
        }

        if type == .flagsChanged && sessionActive && !commandIsDown {
            commitSelection()
        }

        return Unmanaged.passUnretained(event)
    }

    private func beginSession() {
        sessionWindows = windowStore.candidates(scope: ScreenScope.selected)
        guard !sessionWindows.isEmpty else { return }

        selectedIndex = sessionWindows.count > 1 ? 1 : 0
        guard let displayID = windowStore.activeDisplayID,
              let screen = DisplayManager.screen(for: displayID) ?? NSScreen.main else {
            return
        }

        sessionActive = true
        panelController.show(
            windows: sessionWindows,
            selectedIndex: selectedIndex,
            on: screen
        )
    }

    private func advanceSelection() {
        guard !sessionWindows.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % sessionWindows.count
        panelController.select(index: selectedIndex)
    }

    private func commitSelection() {
        guard sessionActive, sessionWindows.indices.contains(selectedIndex) else {
            cancelSession()
            return
        }
        let selectedWindow = sessionWindows[selectedIndex]
        panelController.hide()
        sessionActive = false
        sessionWindows = []
        windowStore.activate(selectedWindow)
    }

    private func cancelSession() {
        panelController.hide()
        sessionActive = false
        sessionWindows = []
    }
}
