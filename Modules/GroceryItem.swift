//
//  GroceryItem.swift
//  Home Management
//
//  Created by Jared Nash on 1/22/26.
//
// Keeping track if something has been purchased or not
import Foundation

struct GroceryItem: Identifiable, Equatable {
    let id: UUID
    var name: String
    var isPurchased: Bool
    var dueDate: Date?

    init(id: UUID = UUID(), name: String, isPurchased: Bool = false, dueDate: Date? = nil) {
        self.id = id
        self.name = name
        self.isPurchased = isPurchased
        self.dueDate = dueDate
    }
}
