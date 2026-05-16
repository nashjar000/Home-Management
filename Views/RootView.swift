//
//  RootView.swift
//  Home Management
//
//  Created by Jared Nash on 2/4/26.
//
import SwiftUI

struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        if appState.session == nil {
            AuthView()
        } else if appState.profile == nil {
            ProgressView("Loading profile...")
                .task { await loadProfile() }
        } else if appState.household == nil {
            HouseholdSetupView()
        } else {
            ContentView()
        }
    }

    private func loadProfile() async {
        do {
            let profile = try await AuthService.fetchMyProfile()
            await MainActor.run { appState.profile = profile }
        } catch {
            print("Failed to load profile:", error)
        }
    }
}
