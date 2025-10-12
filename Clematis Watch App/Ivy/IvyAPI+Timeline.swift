//
//  IvyAPI+Timeline.swift
//  Clematis
//
//  Created by Evan Plant on 21/08/2025.
//

import Foundation

extension IvyAPI {
    func fetchTimeline(page: Int? = nil, size: Int? = nil, anchor: Int? = nil) async throws -> TimelineData {
        var comps = URLComponents(string: "https://apivi.a1429.lol/timelines/graph")!
        comps.queryItems = [
            page.map   { URLQueryItem(name: "page", value: "\($0)") },
            size.map   { URLQueryItem(name: "size", value: "\($0)") },
            anchor.map { URLQueryItem(name: "anchor", value: "\($0)") },
            URLQueryItem(name: "c_max", value: "3"),
            URLQueryItem(name: "c_overflow", value: "trunc"),
            URLQueryItem(name: "l_max", value: "3"),
            URLQueryItem(name: "l_overflow", value: "trunc")
        ].compactMap { $0 }

        var req = URLRequest(url: comps.url!)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("ios/5.7.0", forHTTPHeaderField: "X-Vine-Client")
        req.setValue("Vine/568 (iPhone; iOS 26.0; Scale/3.00)", forHTTPHeaderField: "User-Agent")
        if let sid = self.vineSessionID { req.setValue(sid, forHTTPHeaderField: "vine-session-id") }
        if let php = self.phpSessionID { req.setValue("PHPSESSID=\(php)", forHTTPHeaderField: "Cookie") }

        print("➡️ GET \(req.url!.absoluteString)")
        print("   vine-session-id:", self.vineSessionID ?? "<nil>")
        print("   Cookie: PHPSESSID=\(self.phpSessionID ?? "<nil>")")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        print("⬅️ Status: \(http.statusCode)")

        guard (200...299).contains(http.statusCode) else {
            if let s = String(data: data, encoding: .utf8) { print("⬅️ Body:", s.prefix(400)) }
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(TimelineEnvelope.self, from: data)
        guard decoded.success, let payload = decoded.data else { throw URLError(.cannotParseResponse) }
        return payload
    }
}
