import AppKit
import ApplicationServices

private func accessibilityObserverCallback(
    observer: AXObserver,
    element: AXUIElement,
    notification: CFString,
    refcon: UnsafeMutableRawPointer?
) {
    guard let refcon else { return }
    let store = Unmanaged<WindowStore>.fromOpaque(refcon).takeUnretainedValue()
    store.accessibilityStateDidChange()
}

final class WindowStore {
    private(set) var windows: [SwitchableWindow] = []
    private var observers: [pid_t: AXObserver] = [:]
    private var workspaceTokens: [NSObjectProtocol] = []
    private var refreshWorkItem: DispatchWorkItem?
    private var recency: [WindowKey: Int64] = [:]
    private var recencyClock: Int64 = 0
    private var activeWindowKey: WindowKey?
    private(set) var activeDisplayID: CGDirectDisplayID?

    init() {
        observeWorkspace()
        refreshNow()
    }

    deinit {
        let center = NSWorkspace.shared.notificationCenter
        workspaceTokens.forEach(center.removeObserver)
    }

    func candidates(scope: ScreenScope) -> [SwitchableWindow] {
        windows
            .filter { scope == .all || $0.displayID == activeDisplayID }
            .sorted { left, right in
                let leftRank = recency[left.key] ?? 0
                let rightRank = recency[right.key] ?? 0
                if leftRank != rightRank { return leftRank > rightRank }
                return left.displayTitle.localizedCaseInsensitiveCompare(right.displayTitle) == .orderedAscending
            }
    }

    func activate(_ window: SwitchableWindow) {
        promote(window.key)

        if window.isMinimized {
            AXUIElementSetAttributeValue(
                window.element,
                kAXMinimizedAttribute as CFString,
                kCFBooleanFalse
            )
        }

        window.application.activate(options: [.activateIgnoringOtherApps])
        AXUIElementSetAttributeValue(
            window.element,
            kAXMainAttribute as CFString,
            kCFBooleanTrue
        )
        AXUIElementSetAttributeValue(
            window.element,
            kAXFocusedAttribute as CFString,
            kCFBooleanTrue
        )
        AXUIElementPerformAction(window.element, kAXRaiseAction as CFString)
        activeWindowKey = window.key
        activeDisplayID = window.displayID
    }

    func accessibilityStateDidChange() {
        scheduleRefresh()
    }

    func reload() {
        refreshNow()
    }

    private func observeWorkspace() {
        let center = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.didHideApplicationNotification,
            NSWorkspace.didUnhideApplicationNotification,
            NSWorkspace.activeSpaceDidChangeNotification
        ]

        workspaceTokens = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.scheduleRefresh()
            }
        }
    }

    private func scheduleRefresh() {
        refreshWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.refreshNow() }
        refreshWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03, execute: item)
    }

    private func refreshNow() {
        let runningApplications = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier
        }
        let onscreenWindows = currentSpaceWindowDescriptions()
        let allWindows = allWindowDescriptions()
        var refreshed: [SwitchableWindow] = []

        for application in runningApplications {
            let appElement = AXUIElementCreateApplication(application.processIdentifier)
            installObserverIfNeeded(for: application.processIdentifier, applicationElement: appElement)

            guard let appWindows: [AXUIElement] = attribute(appElement, kAXWindowsAttribute as CFString) else {
                continue
            }

            for element in appWindows {
                guard isStandardWindow(element) else { continue }
                installWindowNotifications(element, pid: application.processIdentifier)

                let title: String = attribute(element, kAXTitleAttribute as CFString) ?? ""
                guard let frame = frame(of: element) else { continue }
                let minimized: Bool = attribute(element, kAXMinimizedAttribute as CFString) ?? false

                let windowDescription = matchingDescription(
                    pid: application.processIdentifier,
                    title: title,
                    frame: frame,
                    descriptions: onscreenWindows
                )
                if !minimized && windowDescription == nil {
                    continue
                }

                guard let displayID = DisplayManager.displayID(for: frame) else { continue }
                let identityDescription = windowDescription ?? matchingDescription(
                    pid: application.processIdentifier,
                    title: title,
                    frame: frame,
                    descriptions: allWindows
                )
                let accessibilityWindowNumber: NSNumber? = attribute(element, "AXWindowNumber" as CFString)
                guard let windowID = accessibilityWindowNumber?.uint32Value ?? identityDescription?.id else {
                    continue
                }
                let key = WindowKey(pid: application.processIdentifier, windowID: windowID)
                refreshed.append(SwitchableWindow(
                    key: key,
                    element: element,
                    application: application,
                    title: title,
                    frame: frame,
                    displayID: displayID,
                    windowID: windowID,
                    isMinimized: minimized
                ))
            }
        }

        windows = refreshed
        let validKeys = Set(refreshed.map(\.key))
        recency = recency.filter { validKeys.contains($0.key) }
        if recency.isEmpty {
            seedRecency(from: onscreenWindows, validKeys: validKeys)
        }
        updateActiveWindow()
    }

    private func updateActiveWindow() {
        guard let frontmost = NSWorkspace.shared.frontmostApplication else { return }
        let appElement = AXUIElementCreateApplication(frontmost.processIdentifier)
        guard let focused: AXUIElement = attribute(appElement, kAXFocusedWindowAttribute as CFString),
              let focusedWindow = windows.first(where: {
                  $0.application.processIdentifier == frontmost.processIdentifier && CFEqual($0.element, focused)
              }) else {
            return
        }
        let key = focusedWindow.key

        if activeWindowKey != key {
            promote(key)
            activeWindowKey = key
        }
        activeDisplayID = windows.first(where: { $0.key == key })?.displayID ?? activeDisplayID
    }

    private func promote(_ key: WindowKey) {
        recencyClock += 1
        recency[key] = recencyClock
    }

    private func seedRecency(from descriptions: [WindowDescription], validKeys: Set<WindowKey>) {
        for description in descriptions.reversed() {
            let key = WindowKey(pid: description.pid, windowID: description.id)
            if validKeys.contains(key) {
                promote(key)
            }
        }
    }

    private func installObserverIfNeeded(for pid: pid_t, applicationElement: AXUIElement) {
        guard observers[pid] == nil else { return }
        var observer: AXObserver?
        guard AXObserverCreate(pid, accessibilityObserverCallback, &observer) == .success,
              let observer else { return }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        AXObserverAddNotification(observer, applicationElement, kAXWindowCreatedNotification as CFString, refcon)
        AXObserverAddNotification(observer, applicationElement, kAXFocusedWindowChangedNotification as CFString, refcon)
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        observers[pid] = observer
    }

    private func installWindowNotifications(_ window: AXUIElement, pid: pid_t) {
        guard let observer = observers[pid] else { return }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let notifications = [
            kAXUIElementDestroyedNotification,
            kAXWindowMiniaturizedNotification,
            kAXWindowDeminiaturizedNotification,
            kAXTitleChangedNotification,
            kAXMovedNotification,
            kAXResizedNotification
        ]
        notifications.forEach {
            AXObserverAddNotification(observer, window, $0 as CFString, refcon)
        }
    }

    private func isStandardWindow(_ element: AXUIElement) -> Bool {
        let role: String? = attribute(element, kAXRoleAttribute as CFString)
        guard role == (kAXWindowRole as String) else { return false }
        let subrole: String? = attribute(element, kAXSubroleAttribute as CFString)
        return subrole == nil || subrole == (kAXStandardWindowSubrole as String) || subrole == (kAXDialogSubrole as String)
    }

    private func frame(of element: AXUIElement) -> CGRect? {
        guard let positionValue: AXValue = attribute(element, kAXPositionAttribute as CFString),
              let sizeValue: AXValue = attribute(element, kAXSizeAttribute as CFString) else {
            return nil
        }
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue, .cgPoint, &position),
              AXValueGetValue(sizeValue, .cgSize, &size) else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    private func attribute<T>(_ element: AXUIElement, _ name: CFString) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name, &value) == .success else { return nil }
        return value as? T
    }

    private struct WindowDescription {
        let id: CGWindowID
        let pid: pid_t
        let title: String
        let bounds: CGRect
    }

    private func currentSpaceWindowDescriptions() -> [WindowDescription] {
        windowDescriptions(options: [.optionOnScreenOnly, .excludeDesktopElements])
    }

    private func allWindowDescriptions() -> [WindowDescription] {
        windowDescriptions(options: [.optionAll, .excludeDesktopElements])
    }

    private func windowDescriptions(options: CGWindowListOption) -> [WindowDescription] {
        guard let raw = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        return raw.compactMap { info in
            guard (info[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
                  let pid = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value,
                  let boundsDictionary = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDictionary) else {
                return nil
            }
            guard let windowID = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value else {
                return nil
            }
            return WindowDescription(
                id: windowID,
                pid: pid,
                title: info[kCGWindowName as String] as? String ?? "",
                bounds: bounds
            )
        }
    }

    private func matchingDescription(
        pid: pid_t,
        title: String,
        frame: CGRect,
        descriptions: [WindowDescription]
    ) -> WindowDescription? {
        descriptions.first { description in
            guard description.pid == pid else { return false }
            let sameFrame = abs(description.bounds.minX - frame.minX) < 3 &&
                abs(description.bounds.minY - frame.minY) < 3 &&
                abs(description.bounds.width - frame.width) < 3 &&
                abs(description.bounds.height - frame.height) < 3
            return sameFrame || (!title.isEmpty && description.title == title)
        }
    }
}
