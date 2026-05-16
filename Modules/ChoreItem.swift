//
//  ChoreItem.swift
//  Home Management
//
//  Created by Jared Nash on 1/29/26.
//
import Foundation

struct ChoreItem: Identifiable, Equatable {
    let id: UUID
    var title: String
    var isDone: Bool
    
    init(id: UUID = UUID(), title: String, isDone: Bool = false) {
        self.id = id
        self.title = title
        self.isDone = isDone
    }
}

