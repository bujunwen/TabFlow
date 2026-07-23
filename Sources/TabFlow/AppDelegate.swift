import AppKit
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowStore: WindowStore!
    private var panelController: SwitcherPanelController!
    private var eventTapManager: EventTapManager!
    private var statusMenuController: StatusMenuController!
    private var permissionTimer: Timer?
    private var accessibilityWasTrusted = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)

        windowStore = WindowStore()
        panelController = SwitcherPanelController()
        eventTapManager = EventTapManager(
            windowStore: windowStore,
            panelController: panelController
        )
        statusMenuController = StatusMenuController(eventTapManager: eventTapManager)

        requestAccessibilityPermission()
        refreshPermissionState()
        permissionTimer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(refreshPermissionState),
            userInfo: nil,
            repeats: true
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate()
        eventTapManager.stop()
    }

    private func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    @objc private func refreshPermissionState() {
        let isTrusted = AXIsProcessTrusted()
        statusMenuController.updatePermissionState(isTrusted: isTrusted)
        if isTrusted && !accessibilityWasTrusted {
            windowStore.reload()
        }
        accessibilityWasTrusted = isTrusted

        if isTrusted && eventTapManager.start() {
            permissionTimer?.invalidate()
            permissionTimer = nil
        }
    }
}
