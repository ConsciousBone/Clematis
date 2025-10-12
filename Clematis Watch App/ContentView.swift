//
//  ContentView.swift
//  Clematis Watch App
//
//  Created by Evan Plant on 21/08/2025.
//
import SwiftUI
import AVKit
import AVFoundation

struct ContentView: View {
    @StateObject private var api = IvyAPI.shared
    @StateObject private var store = TimelineStore()

    @AppStorage("ivy_username") private var storedUsername: String = ""

    @State private var showingMenu = false
    @State private var showingInfo = false
    @State private var showingPlayer = false

    @State private var showingSignInPrompt = false
    @State private var showingAccountSheet = false
    @State private var didCheckForCreds = false

    private var currentPost: IvyPost? {
        (0..<store.posts.count).contains(store.currentIndex) ? store.posts[store.currentIndex] : nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // blurred, dimmed thumbnail bg
                if let thumbURL = currentPost?.thumbnailUrl {
                    AsyncImage(url: thumbURL) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFill().blur(radius: 20)
                                .overlay(Color.black.opacity(0.45))
                                .ignoresSafeArea()
                        default:
                            Color.black.ignoresSafeArea()
                        }
                    }
                } else { Color.black.ignoresSafeArea() }

                // foreground
                VStack(spacing: 10) {
                    if let post = currentPost {
                        Text(post.displayUsername)
                            .font(.headline).lineLimit(1).foregroundStyle(.white)
                        if let desc = post.description, !desc.isEmpty {
                            Text(desc).font(.footnote).lineLimit(2)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(.horizontal, 6)
                        }
                    } else {
                        if store.loading {
                            ProgressView("Loading…").tint(.white)
                        } else {
                            VStack(spacing: 4) {
                                Text("No video").font(.headline).foregroundStyle(.white)
                                Text("Are you signed in?").font(.footnote).foregroundStyle(.secondary)
                                Text("Open the menu, then navigate to Account.")
                                    .font(.footnote).multilineTextAlignment(.center)
                                    .foregroundStyle(.secondary)
                            }.padding(.horizontal, 6)
                        }
                    }
                }.padding()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingMenu.toggle() } label: { Label("Menu", systemImage: "list.bullet") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingInfo.toggle() } label: { Label("Info", systemImage: "info") }
                        .disabled(currentPost == nil)
                        .foregroundStyle(Color.white)
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Button {
                        store.currentIndex = max(0, store.currentIndex - 1)
                    } label: { Label("Previous", systemImage: "backward") }
                    .disabled(store.currentIndex == 0 || store.posts.isEmpty)

                    Button {
                        showingPlayer = true
                    } label: { Label("Play Video", systemImage: "play") }
                    .controlSize(.large)

                    Button {
                        let nextIndex = store.currentIndex + 1
                        store.currentIndex = min(store.posts.count - 1, nextIndex)
                        Task { await store.loadMoreIfNeeded(current: nextIndex) }
                    } label: { Label("Next", systemImage: "forward") }
                    .disabled(store.posts.isEmpty)
                }
            }
            .sheet(isPresented: $showingMenu) { MenuView() }
            .sheet(isPresented: $showingInfo) {
                if let post = currentPost { InfoView(post: post) }
            }
            .sheet(isPresented: $showingPlayer) {
                if let url = currentPost?.primaryVideoURL {
                    VideoSheet(url: url).id(url.absoluteString)
                } else { Text("No playable URL").padding() }
            }
            .sheet(isPresented: $showingAccountSheet) { AccountView() }
            .alert("No account detected", isPresented: $showingSignInPrompt) {
                Button("Sign In") { showingAccountSheet = true }
                Button("Cancel", role: .cancel) {}
            } message: { Text("Do you want to sign in?") }
            .task {
                guard !didCheckForCreds else { return }
                didCheckForCreds = true

                let hasPassword = SecureStore.loadString(account: SecureStore.Account.password) != nil
                if storedUsername.isEmpty || !hasPassword {
                    showingSignInPrompt = true
                } else {
                    await IvyAPI.shared.autoLoginIfPossible()
                    await store.loadInitial()
                }
            }
            .onChange(of: api.isAuthenticated) { _, newValue in
                if newValue { Task { await store.loadInitial() } }
            }
            .navigationTitle("Clematis")
        }
    }
}

// MARK: InfoView
struct InfoView: View {
    let post: IvyPost

    @State private var showReport = false

    var avatarURL: URL? { post.displayAvatarURL }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    if let a = avatarURL {
                        AsyncImage(url: a) { phase in
                            switch phase {
                            case .success(let img): img.resizable().scaledToFill()
                            case .failure(_): Color.gray
                            default: ProgressView()
                            }
                        }
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                    }

                    Text(post.displayUsername)
                        .font(.headline)

                    if let desc = post.description, !desc.isEmpty {
                        Text(desc)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 6)
                    }

                    VStack(spacing: 12) {
                        Label("^[\(post.likeCount) like](inflect: true)", systemImage: "hand.thumbsup")
                            .font(.caption)
                        Label("^[\(post.loopCount) loop](inflect: true)", systemImage: "repeat")
                            .font(.caption)
                    }
                    .padding(.top, 4)

                    Divider().padding(.vertical, 8)

                    Button(role: .none) {
                        showReport = true
                    } label: {
                        Label("Report Post", systemImage: "exclamationmark.bubble")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
                .padding()
            }
            .navigationTitle("Info")
            .sheet(isPresented: $showReport) {
                ReportReasonsView(post: post)
            }
        }
    }
}

// MARK: ReportReasonsView
struct ReportReasonsView: View {
    let post: IvyPost

    @Environment(\.dismiss) private var dismiss
    @State private var category: ComplaintCategory?
    @State private var loading: Bool = true
    @State private var errorText: String?
    @State private var pendingChoice: ComplaintChoice?
    @State private var showConfirm: Bool = false
    @State private var showResult: Bool = false
    @State private var resultText: String = "Your report has been submitted."

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView("Loading reasons…")
                } else if let errorText {
                    VStack(spacing: 8) {
                        Text("Failed to load reasons").bold()
                        Text(errorText).font(.footnote).foregroundStyle(.secondary)
                        Button("Close") { dismiss() }
                            .buttonStyle(.borderedProminent)
                    }
                } else if let cat = category {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(cat.prompt)
                                .font(.headline)
                                .padding(.bottom, 4)

                            ForEach(cat.choices) { choice in
                                Button {
                                    pendingChoice = choice
                                    showConfirm = true
                                } label: {
                                    HStack {
                                        Text(choice.title)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding()
                    }
                } else {
                    Text("No reasons available.")
                }
            }
            .navigationTitle("Report Post")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await loadReasons()
            }
            .alert("Confirm report",
                   isPresented: $showConfirm,
                   presenting: pendingChoice) { choice in
                Button("Cancel", role: .cancel) {}
                Button("Report", role: .destructive) {
                    Task { await submit(choice: choice) }
                }
            } message: { choice in
                Text("Report this post for “\(choice.title)”?")
            }
            .alert("Thank you", isPresented: $showResult) {
                Button("OK") { dismiss() }
            } message: {
                Text(resultText)
            }
        }
    }

    // MARK: - Actions

    private func loadReasons() async {
        loading = true
        errorText = nil
        do {
            let cat = try await IvyAPI.shared.fetchPostComplaintMenu()
            await MainActor.run {
                self.category = cat
                self.loading = false
            }
        } catch {
            await MainActor.run {
                self.loading = false
                self.errorText = error.localizedDescription
            }
        }
    }

    private func submit(choice: ComplaintChoice) async {
        do {
            let ok = try await IvyAPI.shared.submitPostComplaint(postId: post.id, code: choice.value)
            await MainActor.run {
                self.resultText = choice.confirmation
                self.showResult = ok
            }
        } catch {
            await MainActor.run {
                self.resultText = "Failed to submit report. Please try again later."
                self.showResult = true
            }
        }
    }
}

// MARK: VideoSheet
private struct VideoSheet: View {
    let url: URL
    @State private var player = AVPlayer()
    @State private var statusObserver: NSKeyValueObservation?

    var body: some View {
        VideoPlayer(player: player)
            .ignoresSafeArea()
            .onAppear { prepareAndPlay() }
            .onChange(of: url) { _, _ in prepareAndPlay() }
            .onDisappear {
                player.pause()
                player.replaceCurrentItem(with: nil)
                statusObserver?.invalidate()
                statusObserver = nil
                NotificationCenter.default.removeObserver(self)
            }
    }

    private func prepareAndPlay(retryCount: Int = 0) {
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)

        statusObserver?.invalidate()
        statusObserver = item.observe(\.status, options: [.new, .initial]) { _, _ in
            DispatchQueue.main.async {
                switch item.status {
                case .readyToPlay: player.play()
                case .failed:
                    if retryCount < 1 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            prepareAndPlay(retryCount: retryCount + 1)
                        }
                    }
                default: break
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            player.seek(to: .zero); player.play()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if item.status != .readyToPlay && retryCount < 1 {
                prepareAndPlay(retryCount: retryCount + 1)
            }
        }
    }
}

#Preview { ContentView() }
