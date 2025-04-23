import Foundation
import Firebase
import FirebaseFirestore

struct Comment: Identifiable, Codable {
    @DocumentID var id: String?
    let postId: String
    let authorId: String
    let authorName: String
    let authorUsername: String
    let authorProfileImageURL: URL?
    let text: String
    let createdAt: Date
    let likes: Int
    let isLiked: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case postId
        case authorId
        case authorName
        case authorUsername
        case authorProfileImageURL
        case text
        case createdAt
        case likes
        case isLiked
    }
    
    init(id: String? = nil,
         postId: String,
         authorId: String,
         authorName: String,
         authorUsername: String,
         authorProfileImageURL: URL? = nil,
         text: String,
         createdAt: Date = Date(),
         likes: Int = 0,
         isLiked: Bool = false) {
        self.id = id
        self.postId = postId
        self.authorId = authorId
        self.authorName = authorName
        self.authorUsername = authorUsername
        self.authorProfileImageURL = authorProfileImageURL
        self.text = text
        self.createdAt = createdAt
        self.likes = likes
        self.isLiked = isLiked
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(String.self, forKey: .id)
        postId = try container.decode(String.self, forKey: .postId)
        authorId = try container.decode(String.self, forKey: .authorId)
        authorName = try container.decode(String.self, forKey: .authorName)
        authorUsername = try container.decode(String.self, forKey: .authorUsername)
        
        if let profileImageURLString = try container.decodeIfPresent(String.self, forKey: .authorProfileImageURL) {
            authorProfileImageURL = URL(string: profileImageURLString)
        } else {
            authorProfileImageURL = nil
        }
        
        text = try container.decode(String.self, forKey: .text)
        
        if let timestamp = try container.decodeIfPresent(Timestamp.self, forKey: .createdAt) {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = Date()
        }
        
        likes = try container.decodeIfPresent(Int.self, forKey: .likes) ?? 0
        isLiked = try container.decodeIfPresent(Bool.self, forKey: .isLiked) ?? false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(postId, forKey: .postId)
        try container.encode(authorId, forKey: .authorId)
        try container.encode(authorName, forKey: .authorName)
        try container.encode(authorUsername, forKey: .authorUsername)
        try container.encodeIfPresent(authorProfileImageURL?.absoluteString, forKey: .authorProfileImageURL)
        try container.encode(text, forKey: .text)
        try container.encode(Timestamp(date: createdAt), forKey: .createdAt)
        try container.encode(likes, forKey: .likes)
        try container.encode(isLiked, forKey: .isLiked)
    }
    
    func withUpdatedLikeStatus(isLiked: Bool) -> Comment {
        let newLikes = isLiked ? self.likes + 1 : max(0, self.likes - 1)
        return Comment(
            id: id,
            postId: postId,
            authorId: authorId,
            authorName: authorName,
            authorUsername: authorUsername,
            authorProfileImageURL: authorProfileImageURL,
            text: text,
            createdAt: createdAt,
            likes: newLikes,
            isLiked: isLiked
        )
    }
    
    // Preview data
    static var previewComments: [Comment] {
        [
            Comment(
                id: "comment1",
                postId: "1",
                authorId: "user456",
                authorName: "John Doe",
                authorUsername: "johndoe",
                authorProfileImageURL: URL(string: "https://randomuser.me/api/portraits/men/32.jpg"),
                text: "Great audio post! I really enjoyed listening to your thoughts.",
                createdAt: Date().addingTimeInterval(-3600),
                likes: 5,
                isLiked: true
            ),
            Comment(
                id: "comment2",
                postId: "1",
                authorId: "user789",
                authorName: "Sarah Johnson",
                authorUsername: "sarahj",
                authorProfileImageURL: URL(string: "https://randomuser.me/api/portraits/women/22.jpg"),
                text: "This resonated with me so much. Thanks for sharing!",
                createdAt: Date().addingTimeInterval(-7200),
                likes: 3,
                isLiked: false
            ),
            Comment(
                id: "comment3",
                postId: "1",
                authorId: "user101",
                authorName: "Mike Wilson",
                authorUsername: "mikew",
                authorProfileImageURL: URL(string: "https://randomuser.me/api/portraits/men/45.jpg"),
                text: "Would love to hear more on this topic in future posts.",
                createdAt: Date().addingTimeInterval(-10800),
                likes: 1,
                isLiked: false
            )
        ]
    }
} 