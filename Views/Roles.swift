import Foundation

public enum UserRole: String, Codable, CaseIterable, Sendable {
    case parent
    case child

    public var title: String { rawValue.capitalized }
    public var isParent: Bool { self == .parent }
    public var isChild: Bool { self == .child }
}

public enum MemberRole: String, Codable, CaseIterable, Sendable {
    case parent
    case child

    public var title: String { rawValue.capitalized }
    public var isParent: Bool { self == .parent }
    public var isChild: Bool { self == .child }
}

public extension UserRole {
    init?(string: String?) {
        guard let s = string?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), let v = UserRole(rawValue: s) else { return nil }
        self = v
    }
}

public extension MemberRole {
    init?(string: String?) {
        guard let s = string?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), let v = MemberRole(rawValue: s) else { return nil }
        self = v
    }
}
