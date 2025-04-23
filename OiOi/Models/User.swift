import Foundation

struct User: Identifiable {
    let id: String
    var username: String
    var name: String  // This is the display name
    var email: String
    var bio: String?
    var profileImageURL: URL?
    var followers: Int
    var following: Int
    
    init(id: String,
         username: String,
         name: String,
         email: String,
         bio: String? = nil,
         profileImageURL: URL? = nil,
         followers: Int = 0,
         following: Int = 0) {
        self.id = id
        self.username = username
        self.name = name
        self.email = email
        self.bio = bio
        self.profileImageURL = profileImageURL
        self.followers = followers
        self.following = following
    }
}

extension User {
    static var preview: User {
        User(
            id: "previewUserID",
            username: "johndoe",
            name: "John Doe",
            email: "john@example.com",
            bio: "Audio creator and storyteller 🎙️",
            followers: 1234,
            following: 567
        )
    }
} 