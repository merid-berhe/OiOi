import SwiftUI
import AVFoundation

struct FeedView: View {
    @StateObject private var audioPostService = AudioPostService()
    @State private var selectedTab = 0
    
    var displayPosts: [AudioPost] {
        switch selectedTab {
        case 0: // Following
            // In a real app, you would filter by followed users
            return audioPostService.posts
        case 1: // Trending
            return audioPostService.trendingPosts
        case 2: // Recent
            return audioPostService.posts
        default:
            return audioPostService.posts
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Use a ZStack for the header to ensure full width
            ZStack {
                Text("OiOi")
                    .font(.headline)
                HStack {
                    Spacer()
                    Button(action: {
                        audioPostService.fetchPosts()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .padding(.trailing)
                }
            }
            .padding(.top)
            
            Picker("Feed Type", selection: $selectedTab) {
                Text("Following").tag(0)
                Text("Trending").tag(1)
                Text("Recent").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()
            
            if audioPostService.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .padding()
                    .frame(maxHeight: .infinity)
            } else if let errorMessage = audioPostService.errorMessage {
                VStack {
                    Text("Error loading posts")
                        .font(.headline)
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Try Again") {
                        audioPostService.fetchPosts()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.top)
                }
                .padding()
                .frame(maxHeight: .infinity)
            } else if displayPosts.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "waveform")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No posts found")
                        .font(.headline)
                    Text("Be the first to share your audio!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(displayPosts) { post in
                            AudioPostCard(post: post, onLike: {
                                audioPostService.likePost(post)
                            }, onPlay: {
                                audioPostService.incrementPlays(post)
                            })
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            audioPostService.fetchPosts()
        }
    }
}

struct AudioPostCard: View {
    let post: AudioPost
    let onLike: () -> Void
    let onPlay: () -> Void
    
    @State private var isPlaying = false
    @State private var player: AVPlayer?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(post.authorUsername.prefix(1)).uppercased())
                            .foregroundColor(.gray)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.authorUsername)
                        .font(.headline)
                    Text(post.title)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Menu {
                    Button {
                        // Share action
                        sharePost()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share")
                        }
                    }
                    
                    Button {
                        // Favorite action
                        onLike()
                    } label: {
                        HStack {
                            Image(systemName: "star")
                            Text("Add to Favorites")
                        }
                    }
                    
                    Button(role: .destructive) {
                        // Report action
                    } label: {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                            Text("Report")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                        .padding(8)
                }
            }
            
            // Audio Player
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .frame(height: 60)
                
                HStack {
                    Button(action: {
                        togglePlayback()
                    }) {
                        Circle()
                            .fill(.blue)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.title3)
                                    .foregroundColor(.white)
                            )
                    }
                    
                    Spacer()
                    
                    Text(formatDuration(post.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                .padding(.horizontal)
            }
            
            // Stats and Tags
            HStack(spacing: 16) {
                Button(action: onLike) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart")
                        Text("\(post.likes)")
                    }
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "play.circle")
                    Text("\(post.plays)")
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "bubble.right")
                    Text("0")
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    ForEach(post.tags.prefix(2), id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .id(tag)
                    }
                }
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .onDisappear {
            stopPlayback()
        }
    }
    
    private func togglePlayback() {
        guard let url = post.audioURL else {
            print("Error: Audio URL is nil for post \(post.id ?? "unknown")")
            return // Don't proceed if URL is nil
        }
        
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback(url: url) // Pass the unwrapped URL
            onPlay() // Call the play count incrementer
        }
    }
    
    private func startPlayback(url: URL) { // Expect non-optional URL
        // Ensure previous player is stopped
        stopPlayback()
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            player = AVPlayer(url: url)
            player?.play()
            isPlaying = true
        } catch {
            print("Error setting up audio session or playing: \(error)")
            isPlaying = false
        }
    }
    
    private func stopPlayback() {
        player?.pause()
        isPlaying = false
    }
    
    private func sharePost() {
        // Implementation would depend on how you want to share
        guard let url = URL(string: "https://oioi.app/posts/\(post.id ?? "")") else { return }
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    FeedView()
} 