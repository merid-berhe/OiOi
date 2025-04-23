import Foundation

// MARK: - Audio Post Preview Data
extension AudioPost {
    static let previewPosts: [AudioPost] = [
        AudioPost(
            title: "Morning Thoughts",
            audioURL: URL(string: "file://sample1.m4a")!,
            authorId: "user1",
            authorName: "John Doe",
            authorUsername: "johndoe",
            duration: 125,
            likes: 42,
            plays: 156,
            tags: ["thoughts", "morning"]
        ),
        AudioPost(
            title: "Jazz Session #3",
            audioURL: URL(string: "file://sample2.m4a")!,
            authorId: "user2",
            authorName: "Jazz Master",
            authorUsername: "jazzmaster",
            duration: 180,
            likes: 89,
            plays: 234,
            tags: ["music", "jazz"]
        ),
        AudioPost(
            title: "Tech Talk",
            audioURL: URL(string: "file://sample3.m4a")!,
            authorId: "user3",
            authorName: "Techie",
            authorUsername: "techie",
            duration: 300,
            likes: 67,
            plays: 198,
            tags: ["tech", "coding"]
        )
    ]
    
    static var preview: AudioPost {
        previewPosts[0]
    }
} 