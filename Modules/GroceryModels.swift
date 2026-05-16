//
//  GroceryModels.swift
//  Home Management
//
//  Created by Jared Nash on 1/30/26.
//
import Foundation
import SwiftData

@Model
final class GroceryItemModel {
    var name: String
    var isPurchased: Bool
    var createdAt: Date

    init(name: String, isPurchased: Bool = false, createdAt: Date = .now) {
        self.name = name
        self.isPurchased = isPurchased
        self.createdAt = createdAt
    }
}
