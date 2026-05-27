import AppKit

struct ClipboardService {
    func copy(_ svg: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(svg, forType: .string)
    }
}
