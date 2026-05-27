import AppKit
import SwiftUI

@MainActor
public final class SettingsWindowController {
    public static let shared = SettingsWindowController()

    private var window: NSWindow?

    private init() { }

    public func show(preferences: PreferencesService) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(
            rootView: SettingsView()
                .environmentObject(preferences)
        )

        let newWindow = NSWindow(contentViewController: hostingController)
        newWindow.title = "SVG Ops Settings"
        newWindow.styleMask = [.titled, .closable]
        newWindow.titleVisibility = .visible
        newWindow.titlebarAppearsTransparent = false
        newWindow.isMovableByWindowBackground = false
        newWindow.isOpaque = true
        newWindow.backgroundColor = .windowBackgroundColor
        newWindow.isReleasedWhenClosed = false
        newWindow.setContentSize(NSSize(width: 460, height: 460))
        newWindow.minSize = NSSize(width: 460, height: 460)
        newWindow.maxSize = NSSize(width: 460, height: 460)
        newWindow.center()

        window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
