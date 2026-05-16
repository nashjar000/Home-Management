// Setting parent and child roles

import Foundation

public enum MemberRole: String, Codable, CaseIterable, Sendable {
    case parent
    case child

    public var title: String { rawValue.capitalized }
    public var isParent: Bool { self == .parent }
    public var isChild: Bool { self == .child }
}

public extension MemberRole {
    init?(string: String?) {
        guard let s = string?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), let v = Self(rawValue: s) else { return nil }
        self = v
    }
}

