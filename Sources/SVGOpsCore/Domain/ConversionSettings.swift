import Foundation

public struct ConversionSettings: Codable, Equatable, Sendable {
    public var mode: ConversionMode
    public var quality: ConversionQuality
    public var fillMode: FillMode
    public var customFillHex: String
    public var outputFilenameSuffix: String

    public init(mode: ConversionMode, quality: ConversionQuality, fillMode: FillMode, customFillHex: String, outputFilenameSuffix: String) {
        self.mode = mode
        self.quality = quality
        self.fillMode = fillMode
        self.customFillHex = customFillHex
        self.outputFilenameSuffix = outputFilenameSuffix
    }

    public static let defaults = ConversionSettings(
        mode: .lineArt,
        quality: .balanced,
        fillMode: .currentColor,
        customFillHex: "#000000",
        outputFilenameSuffix: ".vector"
    )
}
