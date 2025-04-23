import Foundation
import Combine
import SwiftUI // For Alert presentation state

// --- FIX: Add @MainActor to the class ---
@MainActor
class RecordViewModel: ObservableObject {
    // Dependencies (Injected or retrieved)
    // Assuming these services are thread-safe or also @MainActor isolated if accessed across threads
    private var audioRecorder: AudioRecorderService
    private var audioPostService: AudioPostService
    private var authService: AuthenticationService

    // Published properties mirroring the View's State (Updates must be on Main Thread)
    @Published var title = ""
    @Published var description = ""
    @Published var tags = ""
    @Published var isUploading = false
    @Published var showingAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""

    // Cancellables set for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    // Computed property for form validity
    var isFormValid: Bool {
        !title.isEmpty && audioRecorder.recordedFileURL != nil
    }

    // Initializer now implicitly runs on MainActor
    init(audioRecorder: AudioRecorderService, audioPostService: AudioPostService, authService: AuthenticationService) {
        self.audioRecorder = audioRecorder
        self.audioPostService = audioPostService
        self.authService = authService
        print("RecordViewModel Initialized")
        // Note: If setupSubscribers or fetch methods do heavy work, consider Task { await ... }
        // setupSubscribers() // Setup might be deferred if init dependencies are complex
    }

    // setupSubscribers is automatically on MainActor now
    // func setupSubscribers() { ... } // If you add subscriptions back

    // publishPost is automatically on MainActor now
    func publishPost() {
        print("RecordViewModel: publishPost called.")
        guard let fileURL = audioRecorder.recordedFileURL else {
            print("RecordViewModel: Publish failed - No recording URL.")
            showAlert(title: "Error", message: "No recording found to publish.")
            return
        }

        // --- FIX: This access is now safe because the method is @MainActor ---
        guard let currentUserProfile = authService.userProfile else {
            print("RecordViewModel: Publish failed - User not logged in.")
            showAlert(title: "Login Required", message: "You must be logged in to publish.")
            return
        }
        // --- END FIX ---
         print("RecordViewModel: User \(currentUserProfile.username) is attempting to publish.")


        let tagArray = tags.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } // Remove empty tags

        isUploading = true // Update published property (safe on MainActor)
         print("RecordViewModel: Starting upload...")


        // Assuming audioPostService.uploadAudioPost returns a Publisher
        // If it's an async func, use Task { await try audioPostService.uploadAudioPost(...) }
        audioPostService.uploadAudioPost(
            title: title,
            description: description.isEmpty ? nil : description,
            audioFileURL: fileURL,
            duration: audioRecorder.recordingTime, // Make sure this is accurate
            tags: tagArray
            // Add other necessary parameters like authorId, authorUsername, etc.
            // authorId: currentUserProfile.id,
            // authorUsername: currentUserProfile.username
        )
        .receive(on: DispatchQueue.main) // Still good practice, though class is MainActor
        .sink(receiveCompletion: { [weak self] completion in
             guard let self = self else { return }
             print("RecordViewModel: Upload completion received.")
             self.isUploading = false // Update published property

            switch completion {
            case .failure(let error):
                print("RecordViewModel: Upload failed: \(error)")
                self.showAlert(title: "Upload Failed", message: error.localizedDescription)
            case .finished:
                 print("RecordViewModel: Upload finished.")
                // Success message is handled in receiveValue
                 break
            }
        }, receiveValue: { [weak self] _ in // Assuming receiveValue gives confirmation or the new post
             guard let self = self else { return }
             print("RecordViewModel: Upload successful (receiveValue).")
            self.showAlert(title: "Success", message: "Your audio post has been published!")
            self.resetForm() // Reset form on success
        })
        .store(in: &cancellables)
    }

    // resetForm is automatically on MainActor now
    func resetForm() {
        print("RecordViewModel: Resetting form.")
        // Reset recorder via service
        audioRecorder.resetRecording() // Assuming this exists and is safe to call
        // Reset published properties
        title = ""
        description = ""
        tags = ""
        // isUploading is handled by the upload flow
    }

    // showAlert is automatically on MainActor now
    func showAlert(title: String, message: String) {
        print("RecordViewModel: Showing alert - Title: \(title), Message: \(message)")
        // Update published properties
        alertTitle = title
        alertMessage = message
        showingAlert = true // This triggers the alert in the View
    }
}
