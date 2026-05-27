import SwiftUI
import SVGOpsCore

@main
struct SVGOpsApp: App {
    @StateObject private var preferences = PreferencesService()

    var body: some Scene {
        Window("SVG Ops", id: "main") {
            MainView()
                .environmentObject(preferences)
                .background(WindowChromeView())
                .frame(width: 980, height: 780)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About SVG Ops") {
                    AboutWindowController.shared.show()
                }
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    SettingsWindowController.shared.show(preferences: preferences)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(replacing: .newItem) { }
        }
    }
}
