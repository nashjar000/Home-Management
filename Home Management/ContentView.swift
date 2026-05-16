//
//  ContentView.swift
//  Home Management
//
//  Created by Jared Nash on 1/17/26.
//
// This is the main skeleton of what people see on the app (the icons at the bottom of the screen mainly)

import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject var choresVM: ChoresViewModel
    @EnvironmentObject var groceryVM: GroceryViewModel
    @EnvironmentObject var appState: AppState

    private var currentUserIsParent: Bool {
        guard let uid = appState.userId else { return false }
        return choresVM.members.first(where: { $0.id == uid })?.member_role.lowercased() == "parent"
    }

    private var choresBadge: Int? {
        guard appState.household != nil else { return nil }

        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())

        let visibleChores = choresVM.chores.filter { chore in
            guard let d = chore.dueDate else { return false }
            let sd = cal.startOfDay(for: d)
            return sd <= startOfToday && !chore.isComplete
        }

        let count: Int
        if currentUserIsParent {
            count = visibleChores.count
        } else if let uid = appState.userId {
            count = visibleChores.filter { $0.assignedTo == uid }.count
        } else {
            count = 0
        }

        return count > 0 ? count : nil
    }

    private var groceriesBadge: Int? {
        guard appState.household != nil else { return nil }
        let count = groceryVM.items.filter { !$0.is_purchased }.count
        return count > 0 ? count : nil
    }
    
    // Tabs on the bottom of screen:
    private enum Tab {
        case home, groceries, chores, calendar, settings
    }

    @State private var selectedTab: Tab = .home
    var body: some View {
        TabView(selection: $selectedTab) {
            // Main home screen (Dashboard) - House picture
            NavigationStack {
                DashboardView()
            }
            .tabItem { Label("Home", systemImage: "house") }
            .tag(Tab.home)
            
            // Groceries tab - Cart picture
            NavigationStack {
                GroceriesView()
            }
            .tabItem { Label("Groceries", systemImage: "cart") }
            .tag(Tab.groceries)
            .tabBadge(groceriesBadge)

            // Chores tab - checklist or broom?
            NavigationStack {
                ChoresListView()
            }
            .tabItem { Label("Chores", systemImage: "checklist") }
            .tag(Tab.chores)
            .tabBadge(choresBadge)

            // Calendar tba - Calendar picture
            NavigationStack {
                CalendarView()
            }
            .tabItem { Label("Calendar", systemImage: "calendar") }
            .tag(Tab.calendar)

            // Settings tab - gear picture
            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(Tab.settings)
        }
    }
}

extension View {
    @ViewBuilder
    func tabBadge(_ value: Int?) -> some View {
        if #available(iOS 15.0, *) {
            if let value {
                self.badge(value)
            } else {
                self
            }
        } else {
            self
        }
    }
}

// Keeping track of the states in the Grocery/Chores/overall App
#Preview {
    ContentView()
        .environmentObject(GroceryViewModel())
        .environmentObject(ChoresViewModel())
        .environmentObject(AppState())
}
