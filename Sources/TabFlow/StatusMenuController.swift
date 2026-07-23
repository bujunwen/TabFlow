import AppKit
import ServiceManagement

final class StatusMenuController: NSObject {
    private let statusItem: NSStatusItem
    private let eventTapManager: EventTapManager
    private let currentScreenItem = NSMenuItem(title: "仅当前屏幕", action: #selector(selectCurrentScreen), keyEquivalent: "")
    private let allScreensItem = NSMenuItem(title: "所有屏幕", action: #selector(selectAllScreens), keyEquivalent: "")
    private let launchAtLoginItem = NSMenuItem(title: "开机自动启动", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")

    init(eventTapManager: EventTapManager) {
        self.eventTapManager = eventTapManager
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        configure()
        configureLaunchAtLoginIfNeeded()
    }

    func updatePermissionState(isTrusted: Bool) {
        if isTrusted {
            statusItem.button?.toolTip = "TabFlow"
        } else {
            statusItem.button?.toolTip = "TabFlow：需要辅助功能权限"
        }
    }

    private func configure() {
        statusItem.button?.image = NSImage(
            systemSymbolName: "rectangle.2.swap",
            accessibilityDescription: "TabFlow"
        )

        let menu = NSMenu()
        let title = NSMenuItem(title: "切换范围", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)

        currentScreenItem.target = self
        allScreensItem.target = self
        menu.addItem(currentScreenItem)
        menu.addItem(allScreensItem)
        menu.addItem(.separator())

        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出 TabFlow", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
        refreshScopeState()
        refreshLaunchAtLoginState()
    }

    @objc private func selectCurrentScreen() {
        ScreenScope.selected = .current
        refreshScopeState()
    }

    @objc private func selectAllScreens() {
        ScreenScope.selected = .all
        refreshScopeState()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            UserDefaults.standard.set(true, forKey: "launchAtLoginConfigured")
            refreshLaunchAtLoginState()
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    @objc private func quit() {
        eventTapManager.stop()
        NSApplication.shared.terminate(nil)
    }

    private func refreshScopeState() {
        currentScreenItem.state = ScreenScope.selected == .current ? .on : .off
        allScreensItem.state = ScreenScope.selected == .all ? .on : .off
    }

    private func configureLaunchAtLoginIfNeeded() {
        if UserDefaults.standard.object(forKey: "tabFlowLoginItemConfigured") == nil {
            do {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
                try SMAppService.mainApp.register()
                UserDefaults.standard.set(true, forKey: "tabFlowLoginItemConfigured")
            } catch {
                NSAlert(error: error).runModal()
            }
        }
        refreshLaunchAtLoginState()
    }

    private func refreshLaunchAtLoginState() {
        launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }
}
