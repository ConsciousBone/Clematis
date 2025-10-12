//
//  IvyPost.swift
//  Clematis
//
//  Created by Evan Plant on 21/08/2025.
//

import Foundation

// MARK: - Top-level timeline envelope
struct TimelineEnvelope: Decodable {
    let code: String?
    let data: TimelineData?
    let success: Bool
    let error: String?
}

struct TimelineData: Decodable {
    let count: Int?
    let records: [IvyPost]
    let previousPage: Int?
    let backAnchor: Int?
    let anchor: Int?
    let nextPage: Int?
}

// MARK: - Flexible types to survive the wild JSON

// Decodes a bool from true/false, 1/0, or "true"/"false"/"1"/"0".
struct FlexibleBool: Decodable {
    let value: Bool
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let b = try? c.decode(Bool.self) { value = b; return }
        if let i = try? c.decode(Int.self) { value = (i != 0); return }
        if let s = try? c.decode(String.self) {
            let ls = s.lowercased()
            if ls == "true" || ls == "1" { value = true; return }
            if ls == "false" || ls == "0" { value = false; return }
        }
        // If it's missing/null, default false rather than throw
        value = false
    }
}

// MARK: - Core model for a post
struct IvyPost: Identifiable, Decodable {
    // Stable identifier
    let id: Int64

    // Core media + text
    let description: String?
    let created: String?
    let duration: Double?

    // Primary direct URLs the API returns
    let videoUrl: URL?
    let videoPreview: URL?
    let videoUrlWebm: URL?
    let videoLowURL: URL?

    // Variant array (h264/webm etc)
    let videoUrls: [VideoVariant]?

    // Thumbnail
    let thumbnailUrl: URL?

    // Share/permalink
    let shareUrl: URL?
    let permalinkUrl: URL?

    // Flat user fields sometimes echoed at post level
    let username: String?
    let avatarUrl: URL?
    let verified: FlexibleBool?   // <— FIX: was Bool, now flexible

    // Canonical nested user object (prefer these)
    let user: IvyUser?

    // Counts
    let likes: CountBox?
    let loops: LoopBox?
    let comments: CountBox?
    let reposts: CountBox?

    // Misc
    let explicitContent: Int?
    let userBackgroundColor: String?
    let profileBackground: String?

    enum CodingKeys: String, CodingKey {
        case id = "postId"
        case description
        case created
        case duration
        case videoUrl
        case videoPreview
        case videoUrlWebm
        case videoLowURL
        case videoUrls
        case thumbnailUrl
        case shareUrl
        case permalinkUrl
        case username
        case avatarUrl
        case verified
        case user
        case likes
        case loops
        case comments
        case reposts
        case explicitContent
        case userBackgroundColor
        case profileBackground
        // case tags
    }
}

// MARK: - Variants like h264/webm with frame rate
struct VideoVariant: Decodable {
    let format: String?
    let rate: Int?
    let videoUrl: URL?
}

// MARK: - The nested user object present on each post
struct IvyUser: Decodable {
    let userId: Int64?
    let username: String?
    let avatarUrl: URL?
    let verified: FlexibleBool?
    let description: String?
    let location: String?
    let profileBackground: String?
    let following: Int?
    let explicitContent: Int?
}

// MARK: - Likes/Comments/Reposts share a common "count" shape
struct CountBox: Decodable {
    let count: Int?
    // records exist but we skip them on watchOS
}

// MARK: - Loops include extra fields but you mostly need the count
struct LoopBox: Decodable {
    let count: Int?
    let velocity: Double?
    let onFire: Int?
}

// MARK: - Convenience computed properties
extension IvyPost {
    // Choose a playable URL: explicit mp4 `videoUrl` first, then a variant with mp4/h264,
    // then low/preview as last resorts.
    var primaryVideoURL: URL? {
        if let u = videoUrl { return u }
        if let v = videoUrls?.first(where: {
            ($0.format?.lowercased().contains("h264") == true) ||
            ($0.videoUrl?.absoluteString.lowercased().hasSuffix(".mp4") == true)
        })?.videoUrl {
            return v
        }
        return videoLowURL ?? videoPreview
    }

    var displayAvatarURL: URL? {
        user?.avatarUrl ?? avatarUrl
    }

    var displayUsername: String {
        user?.username ?? username ?? "Unknown"
    }

    var isVerified: Bool {
        (user?.verified?.value ?? verified?.value) ?? false
    }

    var likeCount: Int { likes?.count ?? 0 }
    var loopCount: Int { loops?.count ?? 0 }
}
