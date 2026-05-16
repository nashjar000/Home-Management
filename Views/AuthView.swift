//
//  AuthView.swift
//  Home Management
//
//  Created by Jared Nash on 2/4/26.
//
// Authentication page (login/create account...simpified version)

import SwiftUI
import Auth

struct AuthView: View {
    @EnvironmentObject var appState: AppState

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var errorMessage: String?
    @State private var selectedRole: UserRole = .parent

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()

                    SecureField("Password", text: $password)
                }

                if isSignUp {
                    Section("Role") {
                        Picker("User Role", selection: $selectedRole) {
                            Text("Parent").tag(UserRole.parent)
                            Text("Child").tag(UserRole.child)
                        }
                        .pickerStyle(.segmented)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button(isSignUp ? "Create Account" : "Sign In") {
                        Task {
                            errorMessage = nil
                            do {
                                if isSignUp {
                                    let session = try await AuthService.signUp(email: email, password: password)
                                    // Ensure a profile exists for new users (default role: user)
                                    let profile = try await AuthService.upsertProfile(userId: session.user.id, role: selectedRole)
                                    await MainActor.run {
                                        appState.session = session
                                        appState.profile = profile
                                    }
                                } else {
                                    let session = try await AuthService.signIn(email: email, password: password)
                                    var profile = try? await AuthService.fetchMyProfile()
                                    if profile == nil, let userId = session.user.id as UUID? {
                                        // Ensure a profile exists if missing; default to child
                                        profile = try? await AuthService.upsertProfile(userId: userId, role: .child)
                                    }
                                    await MainActor.run {
                                        appState.session = session
                                        appState.profile = profile
                                    }
                                }
                            } catch {
                                await MainActor.run { errorMessage = error.localizedDescription }
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(email.isEmpty || password.isEmpty)

                    Button(isSignUp ? "Have an account? Sign in" : "Don't have an account? Create account") {
                        isSignUp.toggle()
                    }
                }
            }
            .navigationTitle("Home Management")
        }
    }
}

