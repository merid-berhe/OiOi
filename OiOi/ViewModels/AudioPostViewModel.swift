import Foundation
import AVFoundation
import SwiftUI
import Combine

class AudioPostViewModel: ObservableObject {
    
    // MARK: - Properties
    @Published var audioPost: AudioPost
    @Published var comments: [Comment] = []
    @Published var isPlaying: Bool = false
    @Published var isLiked: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private var audioPlayer: AVPlayer?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(audioPost: AudioPost) {
        self.audioPost = audioPost
        self.isLiked = audioPost.isLiked
        
        // Load comments for this post
        loadComments()
        
        // Set up audio player if URL is available
        setupAudioPlayer()
    }
    
    deinit {
        if let timeObserver = timeObserver, let player = audioPlayer {
            player.removeTimeObserver(timeObserver)
        }
        pauseAudio()
    }
    
    // MARK: - Audio Player Methods
    
    private func setupAudioPlayer() {
        guard let audioURL = audioPost.audioURL else {
            self.errorMessage = "Audio URL is not available"
            return
        }
        
        let playerItem = AVPlayerItem(url: audioURL)
        audioPlayer = AVPlayer(playerItem: playerItem)
        
        // Add time observer to update current playback time
        timeObserver = audioPlayer?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time.seconds
            
            // Check if playback has reached the end
            if let duration = self.audioPlayer?.currentItem?.duration.seconds,
               time.seconds >= duration {
                self.isPlaying = false
                self.currentTime = 0
                self.audioPlayer?.seek(to: CMTime.zero)
            }
        }
        
        // Observe when playback ends
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)
            .sink { [weak self] _ in
                self?.isPlaying = false
                self?.currentTime = 0
                self?.audioPlayer?.seek(to: CMTime.zero)
            }
            .store(in: &cancellables)
    }
    
    func togglePlayPause() {
        if isPlaying {
            pauseAudio()
        } else {
            playAudio()
        }
    }
    
    func playAudio() {
        guard let player = audioPlayer else {
            setupAudioPlayer()
            guard audioPlayer != nil else { return }
            playAudio()
            return
        }
        
        player.play()
        isPlaying = true
        
        // Increment play count
        incrementPlayCount()
    }
    
    func pauseAudio() {
        audioPlayer?.pause()
        isPlaying = false
    }
    
    func seekTo(time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        audioPlayer?.seek(to: cmTime)
        currentTime = time
    }
    
    // MARK: - Data Methods
    
    func toggleLike() {
        isLiked.toggle()
        
        // Update the post with the new like status
        audioPost = audioPost.withUpdatedLikeStatus(isLiked: isLiked)
        
        // Call API to update like status on server
        updateLikeStatusOnServer()
    }
    
    func incrementPlayCount() {
        // Only increment if this is a new playback
        if currentTime < 1 {
            audioPost = audioPost.incrementedPlays()
            
            // Call API to update play count on server
            updatePlayCountOnServer()
        }
    }
    
    func addComment(text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isLoading = true
        
        // Create a new comment
        let newComment = Comment(
            postId: audioPost.id ?? "",
            authorId: "currentUserId", // In a real app, get from authentication
            authorName: "Current User", // In a real app, get from user profile
            authorUsername: "currentuser", // In a real app, get from user profile
            text: text,
            createdAt: Date()
        )
        
        // Optimistically add it to the UI
        comments.insert(newComment, at: 0)
        
        // In a real app, save to server
        saveCommentToServer(newComment)
        
        isLoading = false
    }
    
    // MARK: - API Calls (Placeholder implementations)
    
    private func loadComments() {
        isLoading = true
        
        // In a real app, fetch from Firebase or other backend
        // For now, using preview data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.comments = Comment.previewComments
            self.isLoading = false
        }
    }
    
    private func updateLikeStatusOnServer() {
        // In a real app, call API to update like status
        // For now, just simulating a network call
        print("Updating like status for post \(audioPost.id ?? "unknown") to \(isLiked)")
    }
    
    private func updatePlayCountOnServer() {
        // In a real app, call API to update play count
        // For now, just simulating a network call
        print("Incrementing play count for post \(audioPost.id ?? "unknown") to \(audioPost.plays)")
    }
    
    private func saveCommentToServer(_ comment: Comment) {
        // In a real app, call API to save comment
        // For now, just simulating a network call
        print("Saving comment to server: \(comment.text)")
    }
    
    // MARK: - Helper Methods
    
    func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
} 