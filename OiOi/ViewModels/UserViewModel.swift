import Foundation
import SwiftUI

class UserViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func fetchUser() {
        isLoading = true
        // Simulate network request
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.currentUser = User(
                id: "previewUserID",
                username: "johndoe",
                name: "John Doe",
                email: "john@example.com",
                bio: "Audio creator and storyteller 🎙️",
                followers: 0,
                following: 0
            )
            self.isLoading = false
        }
    }
    
    func updateUser(_ user: User) {
        currentUser = user
    }
} 