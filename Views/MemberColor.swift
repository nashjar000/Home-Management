// MemberColor.swift
// Helper for stable member color assignment

import SwiftUI

private let memberColorPalette: [Color] = [
    .blue, .green, .orange, .purple, .pink, .teal, .indigo
]

public func memberColor(for uuid: UUID?) -> Color {
    guard let uuid = uuid else { return .gray }
    let str = uuid.uuidString
    let hash = str.unicodeScalars.reduce(0, { ($0 &* 31) &+ UInt32($1.value) })
    let index = Int(hash % UInt32(memberColorPalette.count))
    return memberColorPalette[index]
}
