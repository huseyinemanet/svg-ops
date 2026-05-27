import Foundation

public enum ConversionQuality: String, CaseIterable, Codable, Identifiable, Sendable {
    case clean
    case balanced
    case accurate

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .clean: "Clean"
        case .balanced: "Balanced"
        case .accurate: "Accurate"
        }
    }
}
