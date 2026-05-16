//
//  ContentView.swift
//  Home Management
//
//  Created by Jared Nash on 1/17/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                DashboardView()
            }
            .tabItem { Label("Today", systemImage: "house") }

            NavigationStack {
                GroceriesView()
            }
            .tabItem { Label("Groceries", systemImage: "cart") }

            NavigationStack {
                ChoresView()
            }
            .tabItem { Label("Chores", systemImage: "checklist") }

            NavigationStack {
                CalendarView()
            }
            .tabItem { Label("Calendar", systemImage: "calendar") }

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(GroceryViewModel())
}
