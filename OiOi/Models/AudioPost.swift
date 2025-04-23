import Foundation
import Firebase
import FirebaseFirestore

struct AudioPost: Identifiable, Codable {
    @DocumentID var id: String?
    let title: String
    let description: String?
    let audioURL: URL?
    let authorId: String
    let authorName: String
    let authorUsername: String
    let authorProfileImageURL: URL?
    let createdAt: Date
    let duration: TimeInterval
    let likes: Int
    let plays: Int
    let comments: Int
    let tags: [String]
    let isLiked: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case audioURL
        case authorId
        case authorName
        case authorUsername
        case authorProfileImageURL
        case createdAt
        case duration
        case likes
        case plays
        case comments
        case tags
        case isLiked
    }
    
    init(id: String? = nil,
         title: String,
         description: String? = nil,
         audioURL: URL? = nil,
         authorId: String,
         authorName: String,
         authorUsername: String,
         authorProfileImageURL: URL? = nil,
         createdAt: Date = Date(),
         duration: TimeInterval = 0,
         likes: Int = 0,
         plays: Int = 0,
         comments: Int = 0,
         tags: [String] = [],
         isLiked: Bool = false) {
        self.id = id
        self.title = title
        self.description = description
        self.audioURL = audioURL
        self.authorId = authorId
        self.authorName = authorName
        self.authorUsername = authorUsername
        self.authorProfileImageURL = authorProfileImageURL
        self.createdAt = createdAt
        self.duration = duration
        self.likes = likes
        self.plays = plays
        self.comments = comments
        self.tags = tags
        self.isLiked = isLiked
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        
        if let audioURLString = try container.decodeIfPresent(String.self, forKey: .audioURL) {
            audioURL = URL(string: audioURLString)
        } else {
            audioURL = nil
        }
        
        authorId = try container.decode(String.self, forKey: .authorId)
        authorName = try container.decode(String.self, forKey: .authorName)
        authorUsername = try container.decode(String.self, forKey: .authorUsername)
        
        if let profileImageURLString = try container.decodeIfPresent(String.self, forKey: .authorProfileImageURL) {
            authorProfileImageURL = URL(string: profileImageURLString)
        } else {
            authorProfileImageURL = nil
        }
        
        if let timestamp = try container.decodeIfPresent(Timestamp.self, forKey: .createdAt) {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = Date()
        }
        
        duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration) ?? 0
        likes = try container.decodeIfPresent(Int.self, forKey: .likes) ?? 0
        plays = try container.decodeIfPresent(Int.self, forKey: .plays) ?? 0
        comments = try container.decodeIfPresent(Int.self, forKey: .comments) ?? 0
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        isLiked = try container.decodeIfPresent(Bool.self, forKey: .isLiked) ?? false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(audioURL?.absoluteString, forKey: .audioURL)
        try container.encode(authorId, forKey: .authorId)
        try container.encode(authorName, forKey: .authorName)
        try container.encode(authorUsername, forKey: .authorUsername)
        try container.encodeIfPresent(authorProfileImageURL?.absoluteString, forKey: .authorProfileImageURL)
        try container.encode(Timestamp(date: createdAt), forKey: .createdAt)
        try container.encode(duration, forKey: .duration)
        try container.encode(likes, forKey: .likes)
        try container.encode(plays, forKey: .plays)
        try container.encode(comments, forKey: .comments)
        try container.encode(tags, forKey: .tags)
        try container.encode(isLiked, forKey: .isLiked)
    }
    
    // Convenience methods
    func withUpdatedLikeStatus(isLiked: Bool) -> AudioPost {
        let newLikes = isLiked ? self.likes + 1 : max(0, self.likes - 1)
        return AudioPost(
            id: id,
            title: title,
            description: description,
            audioURL: audioURL,
            authorId: authorId,
            authorName: authorName,
            authorUsername: authorUsername,
            authorProfileImageURL: authorProfileImageURL,
            createdAt: createdAt,
            duration: duration,
            likes: newLikes,
            plays: plays,
            comments: comments,
            tags: tags,
            isLiked: isLiked
        )
    }
    
    func incrementedPlays() -> AudioPost {
        return AudioPost(
            id: id,
            title: title,
            description: description,
            audioURL: audioURL,
            authorId: authorId,
            authorName: authorName,
            authorUsername: authorUsername,
            authorProfileImageURL: authorProfileImageURL,
            createdAt: createdAt,
            duration: duration,
            likes: likes,
            plays: plays + 1,
            comments: comments,
            tags: tags,
            isLiked: isLiked
        )
    }
    
    // Preview data
    static var previewPost: AudioPost {
        AudioPost(
            id: "1",
            title: "Morning Thoughts",
            description: "Just sharing some thoughts on a beautiful morning walk. Hope you enjoy!",
            audioURL: URL(string: "https://example.com/audio/sample.mp3"),
            authorId: "user123",
            authorName: "Jane Smith",
            authorUsername: "janesmith",
            authorProfileImageURL: URL(string: "https://randomuser.me/api/portraits/women/44.jpg"),
            createdAt: Date().addingTimeInterval(-24 * 60 * 60),
            duration: 120,
            likes: 42,
            plays: 128,
            comments: 7,
            tags: ["morning", "thoughts", "meditation", "mindfulness"],
            isLiked: false
        )
    }
} 