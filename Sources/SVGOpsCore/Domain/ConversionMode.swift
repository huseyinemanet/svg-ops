import Foundation

public enum ConversionMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case lineArt = "lineArt"
    case singleColour = "singleColour"
    case twoColours = "twoColours"
    case threeColours = "threeColours"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .lineArt: "Line Art"
        case .singleColour: "Single Colour"
        case .twoColours: "2 Colours"
        case .threeColours: "3 Colours"
        }
    }

    public var requiresPotrace: Bool {
        self == .lineArt || self == .singleColour
    }

    public var requiresVTracer: Bool {
        self == .twoColours || self == .threeColours
    }
}
