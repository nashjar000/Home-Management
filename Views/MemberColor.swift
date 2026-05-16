// MemberColor.swift
// Helper for stable member color assignment (used for the chores ring mainly)

import SwiftUI

private let memberColorPalette: [Color] = [
    .blue, .purple, .green, .orange, .pink, .teal, .indigo
]

// Returns a stable color for a member based on their position in the current household list.
// This avoids collisions like Parent and Child both showing blue just because their UUID hashes
// happened to land on the same palette slot.
public func memberColor(for uuid: UUID?, among memberIDs: [UUID]) -> Color {
    guard let uuid = uuid else { return .gray }

    // Keep the order deterministic so the same household gets the same color assignment
    // across dashboard rings, chore cards, and chips.
    let orderedIDs = memberIDs.sorted { $0.uuidString < $1.uuidString }

    guard let index = orderedIDs.firstIndex(of: uuid) else {
        return .gray
    }

    return memberColorPalette[index % memberColorPalette.count]
}

// Convenience fallback for places that only know one UUID.
// This stays stable, but household-aware color assignment should be preferred anywhere possible.
public func memberColor(for uuid: UUID?) -> Color {
    guard let uuid = uuid else { return .gray }
    return memberColor(for: uuid, among: [uuid])
}
