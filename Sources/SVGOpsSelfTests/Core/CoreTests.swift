import Foundation
import SVGOpsCore

extension SVGOpsSelfTests {
    @MainActor
    static func runCoreTests(_ runner: SelfTestRunner) {
        runner.run("output filename uses suffix") {
            let service = OutputFileService()
            let input = URL(fileURLWithPath: "/tmp/empty-state.png")
            runner.expect(
                service.suggestedOutputURL(for: input, suffix: ".vector").lastPathComponent == "empty-state.vector.svg"
            )
        }

        runner.run("filename collision appends number") {
            let service = OutputFileService()
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: folder) }

            let first = folder.appendingPathComponent("icon.vector.svg")
            let second = folder.appendingPathComponent("icon.vector-2.svg")
            try "one".write(to: first, atomically: true, encoding: .utf8)
            runner.expect(service.availableURL(for: first) == second)
        }

        runner.run("preferences default when store is empty") {
            let suiteName = "svg-ops-tests-\(UUID().uuidString)"
            let store = UserDefaults(suiteName: suiteName)!
            defer { store.removePersistentDomain(forName: suiteName) }
            runner.expect(PreferencesService.load(from: store) == .defaults)
        }

        runner.run("preferences decode from store") {
            let suiteName = "svg-ops-tests-\(UUID().uuidString)"
            let store = UserDefaults(suiteName: suiteName)!
            defer { store.removePersistentDomain(forName: suiteName) }

            var preferences = AppPreferences.defaults
            preferences.defaultSettings.mode = .threeColours
            preferences.copyAfterConversion = false
            let data = try JSONEncoder().encode(preferences)
            store.set(data, forKey: "appPreferences")

            runner.expect(PreferencesService.load(from: store) == preferences)
        }

        runner.run("preferences persist last used conversion settings") {
            let suiteName = "svg-ops-tests-\(UUID().uuidString)"
            let store = UserDefaults(suiteName: suiteName)!
            defer { store.removePersistentDomain(forName: suiteName) }

            let service = PreferencesService(store: store)
            let settings = ConversionSettings(
                mode: .singleColour,
                quality: .accurate,
                fillMode: .original,
                customFillHex: "#111111",
                outputFilenameSuffix: ".vector"
            )

            service.updateLastUsedSettings(settings)
            runner.expect(PreferencesService.load(from: store).defaultSettings == settings)
        }
    }
}
