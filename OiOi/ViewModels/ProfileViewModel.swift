import Foundation
import Combine
import SwiftUI // For UIImage
import PhotosUI // <-- IMPORT ADDED

@MainActor // Ensures UI updates happen on the main thread
class ProfileViewModel: ObservableObject {
    // Dependencies (Injected via init)
    private var authService: AuthenticationService
    private var audioPostService: AudioPostService

    // Published properties synchronized with authService or editing state
    @Published var userProfile: UserProfile?
    @Published var name: String = ""
    @Published var bio: String = ""
    @Published var selectedImage: UIImage? // For image picker

    // UI State
    @Published var isLoading = false // Separate loading state for VM operations (like saving)
    @Published var errorMessage: String?
    @Published var showErrorAlert: Bool = false // <-- ADDED for alert presentation
    @Published var postsCount = 0 // Count derived from audioPostService
    @Published var hasChanges: Bool = false // Track if editable fields have changed

    private var cancellables = Set<AnyCancellable>()

    init(authService: AuthenticationService, audioPostService: AudioPostService) {
        self.authService = authService
        self.audioPostService = audioPostService
        print("ProfileViewModel Initialized") // Debug print
        setupSubscribers()

        // Set initial state from authService synchronously if available
        if let currentProfile = authService.userProfile {
            self.userProfile = currentProfile
            self.updateLocalProfile(currentProfile) // Initialize editing fields
             print("ProfileViewModel: Initialized with existing profile: \(currentProfile.username)")
        } else {
             print("ProfileViewModel: Initialized without existing profile.")
        }
        // Initial posts count fetch or rely on subscriber
        fetchUserPostsCount() // Assuming this updates the userPosts publisher
    }

    // Setup Combine subscribers
    private func setupSubscribers() {
        // Subscribe to the authoritative profile from AuthenticationService
        authService.$userProfile
            .receive(on: DispatchQueue.main) // Ensure updates are on main thread
            .sink { [weak self] profile in
                guard let self = self else { return }
                 print("ProfileViewModel: Received profile update from authService. Username: \(profile?.username ?? "nil")")
                self.userProfile = profile // Update the local published property
                if let p = profile {
                    // Update editing fields ONLY if they haven't been changed by the user
                    if !self.hasChanges {
                         print("ProfileViewModel: Updating local name/bio from received profile.")
                         self.updateLocalProfile(p)
                    } else {
                         print("ProfileViewModel: Ignoring profile update for name/bio as local changes exist.")
                    }
                } else {
                     // Handle user logging out - clear local fields
                     print("ProfileViewModel: User logged out, clearing local profile data.")
                     self.name = ""
                     self.bio = ""
                     self.selectedImage = nil
                     self.postsCount = 0
                     self.hasChanges = false
                }
            }
            .store(in: &cancellables)

        // Subscribe to post count changes from AudioPostService
        audioPostService.$userPosts // Assuming userPosts is the source of truth
            .receive(on: DispatchQueue.main)
            .map { $0.count } // Get the count
            .sink { [weak self] count in
                 print("ProfileViewModel: Received posts count update: \(count)")
                 self?.postsCount = count
            }
            .store(in: &cancellables)

         // Subscribe to changes in local editing fields to track 'hasChanges'
         Publishers.CombineLatest3($name, $bio, $selectedImage)
             .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main) // Add debounce to avoid rapid updates
             .sink { [weak self] (currentName, currentBio, currentImage) in
                 guard let self = self else { return }
                 // Need to compare against the authoritative profile, not the local one
                 guard let originalProfile = self.authService.userProfile else {
                      // If no original profile, changes exist if any field is non-empty/non-nil
                      self.hasChanges = !currentName.isEmpty || !currentBio.isEmpty || currentImage != nil
                      print("ProfileViewModel: Original profile nil. Changes detected: \(self.hasChanges)")
                      return
                 }
                 // Check if text fields differ or if an image has been selected
                 self.hasChanges = currentName != originalProfile.name || currentBio != (originalProfile.bio ?? "") || currentImage != nil
                 print("ProfileViewModel: Changes detected: \(self.hasChanges)")
             }
             .store(in: &cancellables)
    }

    // Update local editing properties from a UserProfile
    private func updateLocalProfile(_ profile: UserProfile) {
        self.name = profile.name
        self.bio = profile.bio ?? ""
        // Don't reset selectedImage here, only when profile changes EXTERNALLY
    }

    // Trigger the audio service to fetch posts (subscriber will update count)
    func fetchUserPostsCount() {
        guard let userId = authService.userProfile?.id else {
             print("ProfileViewModel: Cannot fetch posts count, user ID missing.")
            return
        }
        print("ProfileViewModel: Triggering fetch for user posts (ID: \(userId)).")
        // If fetchUserPosts IS async, wrap in Task: Task { await audioPostService.fetchUserPosts(userId: userId) }
        audioPostService.fetchUserPosts(userId: userId) // Assuming it's sync or handles its own Task
    }

    // Fetch initial profile data if needed
    func fetchInitialDataIfNeeded() async {
        guard self.userProfile == nil else {
             print("ProfileViewModel: fetchInitialDataIfNeeded - Profile already exists.")
            return
        }
        guard let userId = authService.userProfile?.id else {
             print("ProfileViewModel: fetchInitialDataIfNeeded - User ID missing from authService.")
            // Optionally set an error message here if needed
            return
        }

        print("ProfileViewModel: fetchInitialDataIfNeeded - Fetching profile for \(userId)")
        isLoading = true
        errorMessage = nil
        do {
            try await authService.fetchUserProfile(userId: userId)
             print("ProfileViewModel: fetchInitialDataIfNeeded - Fetch completed (subscriber will update state).")
        } catch {
             print("ProfileViewModel: fetchInitialDataIfNeeded - Error fetching profile: \(error)")
            self.errorMessage = "Failed to load profile: \(error.localizedDescription)"
            self.showErrorAlert = true
        }
        isLoading = false
    }

    // Save edited profile data
    // --- FIX: Make saveProfileChanges async ---
    func saveProfileChanges() async -> Bool { // <-- Make async and return Bool
        guard let currentProfile = authService.userProfile else { // Compare against original profile
            errorMessage = "Cannot save: Original profile not found."
            showErrorAlert = true
             print("ProfileViewModel: saveProfileChanges - Error: Original profile missing.")
            return false
        }
        guard hasChanges else {
            print("ProfileViewModel: saveProfileChanges - No changes detected to save.")
            return true // Success (no-op)
        }

        print("ProfileViewModel: Attempting to save profile changes...")
        isLoading = true
        errorMessage = nil

        do {
            // --- FIX: Use await try to call the async service method ---
            // Make sure AuthenticationService has this function, uncommented, marked async throws
             _ = try await authService.updateUserProfile(
                 name: self.name,
                 bio: self.bio,
                 profileImage: self.selectedImage // Pass UIImage?
             )
             print("ProfileViewModel: Profile update successful via service.")
             // Auth listener should update userProfile. Reset local state after successful save.
             self.selectedImage = nil // Clear selected image
             self.hasChanges = false // Reset changes flag
             isLoading = false
             return true // Indicate success

        } catch {
             print("ProfileViewModel: saveProfileChanges - Error: \(error)")
            self.errorMessage = "Failed to save profile: \(error.localizedDescription)"
            self.showErrorAlert = true // Trigger alert
            isLoading = false
            return false // Indicate failure
        }
    }
    // --- END FIX ---


    // Load image data from PhotosPickerItem
    func loadImageFromPickerItem(_ item: PhotosPickerItem?) async {
       guard let item = item else { return }
       print("ProfileViewModel: Loading image from picker item...")
       do {
           let data = try await item.loadTransferable(type: Data.self)
           if let data = data, let uiImage = UIImage(data: data) {
               print("ProfileViewModel: Image loaded successfully from picker.")
               // Update the state variable directly
               selectedImage = uiImage
               // hasChanges will be updated automatically by the Combine subscriber
           } else {
               print("ViewModel: Failed to load image data or create UIImage.")
               errorMessage = "Could not load image data."
               showErrorAlert = true
           }
       } catch {
           print("ViewModel: Error loading transferable: \(error)")
           errorMessage = "Error loading image: \(error.localizedDescription)"
           showErrorAlert = true
       }
   }
}
