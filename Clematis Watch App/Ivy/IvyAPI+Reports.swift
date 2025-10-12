//
//  IvyAPI+Reports.swift
//  Clematis Watch App
//
//  Created by Evan Plant on 27/08/2025.
//

import Foundation

// MARK: - Models

struct ComplaintMenuEnvelope: Decodable {
    let code: String?
    let data: ComplaintMenuData
    let success: Bool
}

struct ComplaintMenuData: Decodable {
    let user: ComplaintCategory?
    let post: ComplaintCategory?
    let comment: ComplaintCategory?
}

struct ComplaintCategory: Decodable {
    let prompt: String
    let choices: [ComplaintChoice]
}

struct ComplaintChoice: Decodable, Identifiable {
    var id: String { value }
    let title: String
    let value: String
    let confirmation: String
}

// MARK: - API

extension IvyAPI {
    // Fetch the report menu (we care about `data.post`)
    func fetchPostComplaintMenu() async throws -> ComplaintCategory {
        guard let url = URL(string: "https://apivi.a1429.lol/complaints/menu") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("ios/5.7.0", forHTTPHeaderField: "X-Vine-Client")
        req.setValue("Vine/568 (iPhone; iOS 26.0; Scale/3.00)", forHTTPHeaderField: "User-Agent")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let sid = self.vineSessionID { req.setValue(sid, forHTTPHeaderField: "vine-session-id") }
        if let php = self.phpSessionID { req.setValue("PHPSESSID=\(php)", forHTTPHeaderField: "Cookie") }

        print("📝 GET \(url.absoluteString)")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        print("⬅️ Report menu status:", http.statusCode)

        guard (200...299).contains(http.statusCode) else {
            if let s = String(data: data, encoding: .utf8) { print("⬅️ Body:", s.prefix(400)) }
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(ComplaintMenuEnvelope.self, from: data)
        guard decoded.success, let postCategory = decoded.data.post else {
            throw URLError(.cannotParseResponse)
        }
        return postCategory
    }

    // Submit a complaint for a post by `postId` with reason code (e.g. "harassment_bullying").
    // Returns true on success.
    func submitPostComplaint(postId: Int64, code: String) async throws -> Bool {
        guard let url = URL(string: "https://apivi.a1429.lol/posts/\(postId)/complaints") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("ios/5.7.0", forHTTPHeaderField: "X-Vine-Client")
        req.setValue("Vine/568 (iPhone; iOS 26.0; Scale/3.00)", forHTTPHeaderField: "User-Agent")
        req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let sid = self.vineSessionID { req.setValue(sid, forHTTPHeaderField: "vine-session-id") }
        if let php = self.phpSessionID { req.setValue("PHPSESSID=\(php)", forHTTPHeaderField: "Cookie") }

        let body = ["code": code]
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        print("🛑 POST \(url.absoluteString) with code=\(code)")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        print("⬅️ Submit report status:", http.statusCode)

        if !(200...299).contains(http.statusCode) {
            if let s = String(data: data, encoding: .utf8) { print("⬅️ Body:", s.prefix(400)) }
            throw URLError(.badServerResponse)
        }

        // Response looks like {"code":"","data":[],"success":true}
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let success = json["success"] as? Bool {
            return success
        }
        // If schema changes, assume OK by 2xx
        return true
    }
}
