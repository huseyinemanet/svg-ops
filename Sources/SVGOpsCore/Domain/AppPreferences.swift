import Foundation

public struct AppPreferences: Codable, Equatable, Sendable {
    public var autoConvertOnDrop: Bool
    public var copyAfterConversion: Bool
    public var saveNextToOriginal: Bool
    public var defaultSettings: ConversionSettings

    public init(autoConvertOnDrop: Bool, copyAfterConversion: Bool, saveNextToOriginal: Bool, defaultSettings: ConversionSettings) {
        self.autoConvertOnDrop = autoConvertOnDrop
        self.copyAfterConversion = copyAfterConversion
        self.saveNextToOriginal = saveNextToOriginal
        self.defaultSettings = defaultSettings
    }

    public static let defaults = AppPreferences(
        autoConvertOnDrop: false,
        copyAfterConversion: true,
        saveNextToOriginal: false,
        defaultSettings: .defaults
    )
}
