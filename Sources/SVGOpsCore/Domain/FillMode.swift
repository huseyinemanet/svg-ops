import Foundation

public enum FillMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case currentColor
    case original
    case custom

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .currentColor: "currentColor"
        case .original: "Original"
        case .custom: "Custom"
        }
    }
}
