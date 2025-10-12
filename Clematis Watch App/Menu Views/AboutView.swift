//
//  AboutView.swift
//  Clematis Watch App
//
//  Created by Evan Plant on 26/08/2025.
//

import SwiftUI

struct AboutView: View {
    // Version vars
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    
    @State private var showingContactSheet = false
    
    var body: some View {
        ScrollView {
            Text("Clematis")
                .font(.title2)
                .padding()
            Text("Version " + appVersion)
            Text("Build " + buildNumber)
                .padding(.bottom)
            
            Button("Contact Developer") {
                showingContactSheet.toggle()
            }
            .sheet(isPresented: $showingContactSheet, content: {
                ContactView()
            })
            .padding()
            
            Button("Ivy ToS") {
                openURL(input: "https://ivy.a1429.lol/help/tos")
            }
            .padding()
            
            Button("Ivy Rules") {
                openURL(input: "https://ivy.a1429.lol/help/rules")
            }
            .padding()
        }
    }
}

#Preview {
    AboutView()
}
