//
//  IvyAPI.swift
//  Clematis
//
//  Created by Evan Plant on 21/08/2025.
//

import Foundation
import Combine

@MainActor
final class IvyAPI: ObservableObject {
    static let shared = IvyAPI()

    // Session/user state
    @Published var username: String? = nil         // profile handle/username
    @Published var email: String? = nil            // login email
    @Published var vineSessionID: String? = nil    // header: "vine-session-id"
    @Published var phpSessionID: String? = nil     // cookie: "PHPSESSID=..."
    @Published var isAuthenticated: Bool = false

    private init() {}

    // MARK: - Authenticate (fresh each launch)
    func authenticate(username loginName: String, password: String) async -> Bool {
        guard let url = URL(string: "https://apivi.a1429.lol/users/authenticate") else { return false }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        let bodyPairs = ["username": loginName, "password": password]
        let body = bodyPairs
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
        req.httpBody = body.data(using: .utf8)

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { return false }

            print("🔐 AUTH status:", http.statusCode)
            if let s = String(data: data, encoding: .utf8) { print("🔐 AUTH body:", s.prefix(400)) }
            guard http.statusCode == 200 else { return false }

            // PHPSESSID from Set-Cookie
            if let setCookie = http.allHeaderFields["Set-Cookie"] as? String,
               let php = Self.extractPHPSession(fromSetCookie: setCookie) {
                self.phpSessionID = php
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataObj = json["data"] as? [String: Any] {

                if let vsid = dataObj["vine-session-id"] as? String { self.vineSessionID = vsid }

                if self.phpSessionID == nil {
                    if let php = dataObj["sessionId"] as? String { self.phpSessionID = php }
                    else if let php = dataObj["sessionKey"] as? String { self.phpSessionID = php }
                    else if let php = dataObj["key"] as? String { self.phpSessionID = php }
                }

                self.username = (dataObj["username"] as? String) ?? loginName
                self.email = (dataObj["email"] as? String) ?? loginName
            }

            self.isAuthenticated = (self.vineSessionID != nil && self.phpSessionID != nil)
            print("✅ Auth OK. vine=\(vineSessionID?.prefix(8) ?? "<nil>") php=\(phpSessionID?.prefix(6) ?? "<nil>") user=\(username ?? "<nil>")")

            // Persist creds AFTER a successful auth
            UserDefaults.standard.set(self.email ?? loginName, forKey: "ivy_username")
            try? SecureStore.saveString(password, account: SecureStore.Account.password)

            return self.isAuthenticated
        } catch {
            print("❌ Auth error:", error)
            self.isAuthenticated = false
            return false
        }
    }

    func logout() {
        username = nil
        email = nil
        vineSessionID = nil
        phpSessionID = nil
        isAuthenticated = false

        // Clear password; keep username so the form can prefill if you want
        SecureStore.delete(account: SecureStore.Account.password)
        print("🚪 Logged out (session cleared)")
    }

    // Auto-login using saved username (UserDefaults) + password (Keychain).
    func autoLoginIfPossible() async {
        let savedUser = UserDefaults.standard.string(forKey: "ivy_username") ?? ""
        let savedPass = SecureStore.loadString(account: SecureStore.Account.password) ?? ""
        guard !savedUser.isEmpty, !savedPass.isEmpty else { return }
        print("🔄 Auto-login as \(savedUser)")
        _ = await authenticate(username: savedUser, password: savedPass)
    }

    // MARK: - Helpers
    private static func extractPHPSession(fromSetCookie setCookie: String) -> String? {
        for part in setCookie.components(separatedBy: ";") {
            let t = part.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("PHPSESSID=") { return String(t.dropFirst("PHPSESSID=".count)) }
        }
        return nil
    }

    // (kept for completeness; not used right now)
    private static func preferredSessionFromJSON(_ data: Data) -> String? {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let top = ["vine-session-id","sessionKey","key","token","authToken","accessToken","access_token"]
            for k in top { if let v = json[k] as? String, !v.isEmpty { return v } }
            if let d = json["data"] as? [String: Any] {
                for k in ["sessionToken","sessionId","key","token","sessionKey"] {
                    if let v = d[k] as? String, !v.isEmpty { return v }
                }
            }
        }
        return nil
    }
}
