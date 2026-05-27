import AppKit
import SwiftUI

@MainActor
public final class AboutWindowController {
    public static let shared = AboutWindowController()

    private var window: NSWindow?

    private init() { }

    public func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(
            rootView: AboutView()
                .background(WindowChromeView(title: "About SVG Ops"))
        )

        let newWindow = NSWindow(contentViewController: hostingController)
        newWindow.title = "About SVG Ops"
        newWindow.styleMask = [.titled, .closable, .fullSizeContentView]
        newWindow.titleVisibility = .hidden
        newWindow.titlebarAppearsTransparent = true
        newWindow.isMovableByWindowBackground = true
        newWindow.isReleasedWhenClosed = false
        newWindow.center()
        newWindow.setFrameAutosaveName("About SVG Ops")

        window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
