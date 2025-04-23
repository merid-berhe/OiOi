import Foundation

struct Channel: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String
    var iconName: String
    var isNSFW: Bool
    var posts: [UUID] // AudioPost IDs in this channel
    var subscribers: [UUID] // User IDs subscribed to this channel
    
    init(id: UUID = UUID(),
         name: String,
         description: String,
         iconName: String,
         isNSFW: Bool = false) {
        self.id = id
        self.name = name
        self.description = description
        self.iconName = iconName
        self.isNSFW = isNSFW
        self.posts = []
        self.subscribers = []
    }
}

// Predefined channels
extension Channel {
    static let defaultChannels: [Channel] = [
        Channel(name: "This Happened Today",
               description: "Share your daily stories and experiences",
               iconName: "calendar"),
        
        Channel(name: "Sports",
               description: "All things sports - commentary, reactions, and highlights",
               iconName: "sportscourt"),
        
        Channel(name: "Music",
               description: "Share your musical creations and covers",
               iconName: "music.note"),
        
        Channel(name: "Comedy",
               description: "Funny moments, jokes, and entertainment",
               iconName: "face.smiling"),
        
        Channel(name: "News & Politics",
               description: "Current events and political commentary",
               iconName: "newspaper"),
        
        Channel(name: "NSFW",
               description: "Adult content - 18+ only",
               iconName: "exclamationmark.triangle",
               isNSFW: true)
    ]
} 