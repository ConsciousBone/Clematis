//
//  MenuView.swift
//  Clematis Watch App
//
//  Created by Evan Plant on 21/08/2025.
//

import SwiftUI

struct MenuView: View {
    @StateObject private var api = IvyAPI.shared
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink(destination: AccountView()) {
                        Label("Account", systemImage: "person.circle")
                    }
                } footer: {
                    if let u = api.username { Text("Signed in as \(u)") }
                    else { Text("Not signed in") }
                }
                
                Section {
                    NavigationLink(destination: AboutView()) {
                        Label("About", systemImage: "info.circle")
                    }
                }
            }
            .navigationTitle("Menu")
        }
    }
}

#Preview {
    MenuView()
}
