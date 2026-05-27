import AppKit
import SwiftUI

public struct WindowChromeView: NSViewRepresentable {
    private let title: String

    public init(title: String = "SVG Ops") {
        self.title = title
    }

    public func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(window: view.window, title: title)
        }
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(window: nsView.window, title: title)
        }
    }

    private func configure(window: NSWindow?, title: String) {
        guard let window else { return }
        window.title = title
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = true
        window.isOpaque = true
        window.backgroundColor = .windowBackgroundColor
        window.toolbar = nil
    }
}
