//
//  ContactPageView.swift
//  Searchino
//
//  Created by Evan Plant on 22/06/25.
//

import SwiftUI

struct ContactView: View { // about
    var body: some View {
        ScrollView {
            VStack {
                Spacer()
                
                Text("Email:")
                    .font(.headline)
                
                // chatgpt worked some magic, so
                // this stops the email from being
                // hyphenated on small displays
                let email = "apps@consciousb.one"
                let displayEmail = email
                  .replacingOccurrences(of: "@", with: "@\u{200B}")  // zero-width space
                Text(displayEmail)
                  .font(.body)
                  .multilineTextAlignment(.center)
                  .foregroundStyle(.secondary)
                  .padding(.bottom)
            }
        }
    }
}

#Preview {
    ContactView()
}
