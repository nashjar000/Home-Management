//
//  Home_ManagementApp.swift
//  Home Management
//
//  Created by Jared Nash on 1/17/26.
//

import SwiftUI
import SwiftData

@main
struct Home_ManagementApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var groceryVM = GroceryViewModel()
    @StateObject private var choresVM = ChoresViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.session == nil {
                    AuthView()
                } else {
                    ContentView()
                }
            }
            .environmentObject(appState)
            .environmentObject(groceryVM)
            .environmentObject(choresVM)
        }
    }
}
