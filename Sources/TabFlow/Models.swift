import AppKit
import ApplicationServices

struct WindowKey: Hashable {
    let pid: pid_t
    let elementHash: Int
}

struct SwitchableWindow {
    let key: WindowKey
    let element: AXUIElement
    let application: NSRunningApplication
    let title: String
    let frame: CGRect
    let displayID: CGDirectDisplayID
    let isMinimized: Bool

    var displayTitle: String {
        let appName = application.localizedName ?? "Unknown"
        return title.isEmpty ? appName : "\(appName)  —  \(title)"
    }
}

enum ScreenScope: String {
    case current
    case all

    static var selected: ScreenScope {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: "screenScope"),
                  let scope = ScreenScope(rawValue: rawValue) else {
                return .current
            }
            return scope
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "screenScope")
        }
    }
}
