import AppKit

struct DisplayInfo {
    let id: CGDirectDisplayID
    let bounds: CGRect
    let screen: NSScreen
}

enum DisplayManager {
    static func displays() -> [DisplayInfo] {
        NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return nil
            }
            let id = CGDirectDisplayID(number.uint32Value)
            return DisplayInfo(id: id, bounds: CGDisplayBounds(id), screen: screen)
        }
    }

    static func displayID(for windowFrame: CGRect) -> CGDirectDisplayID? {
        displays()
            .map { ($0.id, windowFrame.intersection($0.bounds).area) }
            .max(by: { $0.1 < $1.1 })?
            .0
    }

    static func screen(for displayID: CGDirectDisplayID) -> NSScreen? {
        displays().first(where: { $0.id == displayID })?.screen
    }
}

private extension CGRect {
    var area: CGFloat {
        guard !isNull else { return 0 }
        return width * height
    }
}
