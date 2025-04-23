import Firebase
import FirebaseFirestore

struct UserProfile: Identifiable, Codable {
    @DocumentID var id: String?
    let username: String
    let name: String
    let email: String
    var bio: String?
    var profileImageURL: URL?
    var followers: Int
    var following: Int
    var createdAt: Date?
    var updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, username, name, email, bio, profileImageURL, followers, following, createdAt, updatedAt
    }
    
    init(id: String? = nil, 
         username: String, 
         name: String, 
         email: String, 
         bio: String? = nil, 
         profileImageURL: URL? = nil, 
         followers: Int = 0, 
         following: Int = 0, 
         createdAt: Date? = Date(), 
         updatedAt: Date? = nil) {
        self.id = id
        self.username = username
        self.name = name
        self.email = email
        self.bio = bio
        self.profileImageURL = profileImageURL
        self.followers = followers
        self.following = following
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// Convenience extension for previewing
extension UserProfile {
    static var preview: UserProfile {
        UserProfile(
            id: "preview-id",
            username: "johndoe",
            name: "John Doe",
            email: "john@example.com",
            bio: "Audio creator and storyteller 🎙️",
            followers: 1234,
            following: 567
        )
    }
} 