//
//  TimelineStore.swift
//  Clematis Watch App
//
//  Created by Evan Plant on 21/08/2025.
//

import Foundation
import Combine

@MainActor
final class TimelineStore: ObservableObject {
    @Published var posts: [IvyPost] = []
    @Published var currentIndex: Int = 0
    @Published var loading = false

    func loadInitial() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }

        do {
            let data = try await IvyAPI.shared.fetchTimeline()
            self.posts = data.records
            self.currentIndex = 0
        } catch {
            print("❌ loadInitial:", error)
        }
    }

    func loadMoreIfNeeded(current: Int) async {
        guard current >= posts.count - 1 else { return }
        do {
            let data = try await IvyAPI.shared.fetchTimeline(page: 2) // naive paging
            self.posts.append(contentsOf: data.records)
        } catch {
            print("❌ loadMore:", error)
        }
    }
}
