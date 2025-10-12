//
//  AccountView.swift
//  Clematis Watch App
//
//  Created by Evan Plant on 21/08/2025.
//

import SwiftUI

struct AccountView: View {
    @StateObject private var api = IvyAPI.shared

    @AppStorage("ivy_username") private var storedUsername: String = ""
    @State private var password: String = ""          // NOT AppStorage

    @State private var isLoggingIn = false
    @State private var errorMessage: String?
    @State private var showLogoutConfirm = false

    private func login() {
        isLoggingIn = true
        errorMessage = nil
        Task {
            let success = await api.authenticate(username: storedUsername, password: password)
            await MainActor.run {
                isLoggingIn = false
                if !success {
                    errorMessage = "Sign in failed. Please check your credentials."
                }
            }
        }
    }

    private func logoutConfirmed() {
        SecureStore.delete(account: SecureStore.Account.password)
        api.logout()
    }

    var body: some View {
        Form {
            Section { Text(verbatim: "No account? Make one at https://ivy.a1429.lol/") }

            Section {
                TextField("Email", text: $storedUsername)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                SecureField("Password", text: $password)
            }

            Section {
                ZStack {
                    if api.username != nil && !isLoggingIn {
                        Button("Sign Out", role: .destructive) { showLogoutConfirm = true }
                    }
                    if isLoggingIn {
                        ProgressView("Signing in…")
                    }
                    if api.username == nil && !isLoggingIn {
                        Button("Sign In") { login() }
                            .disabled(storedUsername.isEmpty || password.isEmpty)
                    }
                }
            } header: {
                if let u = api.username { Text("Signed in as \(u)") }
                else { Text("Not signed in") }
            }

            if let errorMessage {
                Section { Text(errorMessage).foregroundColor(.red) }
            }
        }
        .onAppear {
            // prefill from Keychain (if present)
            if password.isEmpty {
                password = SecureStore.loadString(account: SecureStore.Account.password) ?? ""
            }
        }
        .alert("Sign out?", isPresented: $showLogoutConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) { logoutConfirmed() }
        } message: { Text("Are you sure you want to sign out?") }
        .navigationTitle("Account")
    }
}

#Preview {
    AccountView()
}
