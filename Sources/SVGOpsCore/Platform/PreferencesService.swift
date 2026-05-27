import Combine
import Foundation

@MainActor
public final class PreferencesService: ObservableObject {
    @Published public var autoConvertOnDrop: Bool { didSet { save() } }
    @Published public var copyAfterConversion: Bool { didSet { save() } }
    @Published public var saveNextToOriginal: Bool { didSet { save() } }
    @Published public var defaultSettings: ConversionSettings { didSet { save() } }

    private let store: UserDefaults
    private let key = "appPreferences"

    public init(store: UserDefaults = .standard) {
        self.store = store
        let loaded = Self.load(from: store, key: key)
        autoConvertOnDrop = loaded.autoConvertOnDrop
        copyAfterConversion = loaded.copyAfterConversion
        saveNextToOriginal = loaded.saveNextToOriginal
        defaultSettings = loaded.defaultSettings
    }

    public var snapshot: AppPreferences {
        AppPreferences(
            autoConvertOnDrop: autoConvertOnDrop,
            copyAfterConversion: copyAfterConversion,
            saveNextToOriginal: saveNextToOriginal,
            defaultSettings: defaultSettings
        )
    }

    public func updateLastUsedSettings(_ settings: ConversionSettings) {
        defaultSettings = settings
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        store.set(data, forKey: key)
    }

    public static func load(from store: UserDefaults, key: String = "appPreferences") -> AppPreferences {
        guard let data = store.data(forKey: key),
              let decoded = try? JSONDecoder().decode(AppPreferences.self, from: data) else {
            return .defaults
        }
        return decoded
    }
}
