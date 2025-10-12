//
//  Functions.swift
//  Clematis Watch App
//
//  Created by Evan Plant on 26/08/2025.
//

import Foundation
import AuthenticationServices

var compiledURL = ""

// MARK: Web browser
func openURL(input: String) {
    guard let url = URL(string: input) else {
        return
    }
    let webView = ASWebAuthenticationSession(
        url: url,
        callbackURLScheme: nil
    ) { _, _ in }
    compiledURL = url.absoluteString
    webView.prefersEphemeralWebBrowserSession = true
    webView.start()
}
