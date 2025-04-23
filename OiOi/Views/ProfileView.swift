import SwiftUI
import PhotosUI // Import needed for EditProfileView's Picker

struct ProfileView: View {
    // Services from the environment
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var audioPostService: AudioPostService

    // StateObject ViewModel initialized correctly via init
    @StateObject private var viewModel: ProfileViewModel

    // Local UI State
    @State private var selectedTab = 0
    @State private var showingSettings = false
    @State private var showingEditProfile = false

    // Initializer accepting dependencies for the ViewModel
    init(authService: AuthenticationService, audioPostService: AudioPostService) {
        // Initialize StateObject with the provided services
        _viewModel = StateObject(wrappedValue: ProfileViewModel(authService: authService, audioPostService: audioPostService))
    }

    var body: some View {
        NavigationView {
            ScrollView {
                // Main content conditional on ViewModel state
                if viewModel.userProfile != nil || viewModel.isLoading {
                    if viewModel.isLoading && viewModel.userProfile == nil {
                        ProgressView("Loading Profile...")
                            .scaleEffect(1.5)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 200)
                    } else if let userProfile = viewModel.userProfile {
                        // --- Profile Content ---
                        VStack(spacing: 0) {
                            ProfileHeaderView(userProfile: userProfile, postsCount: viewModel.postsCount)
                                .padding(.bottom)
                            Button { showingEditProfile = true } label: {
                                Text("Edit Profile")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                            .padding(.horizontal)
                            .padding(.bottom)
                            ProfileTabsView(selectedTab: $selectedTab, posts: audioPostService.userPosts, isLoadingPosts: audioPostService.isLoading)
                        }
                    }
                    // Implicit else for loading=false, profile=nil covered below
                } else { // Error state (Not loading, and profile is nil)
                    // --- Error View ---
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 50)).foregroundColor(.orange)
                        Text("Profile Error").font(.headline)
                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage).font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
                        } else {
                             Text("Could not load profile.").font(.subheadline).foregroundColor(.secondary)
                        }
                        Button { Task { await viewModel.fetchInitialDataIfNeeded() } } label: {
                            Text("Try Again").padding(.horizontal, 20).padding(.vertical, 10).background(Color.blue).foregroundColor(.white).cornerRadius(8)
                        }
                    }
                    .padding().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button { showingSettings = true } label: { Image(systemName: "gearshape.fill") } } }
            .sheet(isPresented: $showingSettings) { SettingsView().environmentObject(authService) }
            .sheet(isPresented: $showingEditProfile) { EditProfileView().environmentObject(viewModel) }
            .task { await viewModel.fetchInitialDataIfNeeded() }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - Subviews (Defined within ProfileView.swift)

struct ProfileHeaderView: View {
    let userProfile: UserProfile // Use REAL UserProfile
    let postsCount: Int
    var body: some View { /* ... Implementation from previous step ... */ }
}

struct StatItem: View {
    let value: Int; let label: String
    var body: some View { /* ... Implementation from previous step ... */ }
}

struct ProfileTabsView: View {
    @Binding var selectedTab: Int
    let posts: [AudioPost] // Use REAL AudioPost
    let isLoadingPosts: Bool
    var body: some View { /* ... Implementation from previous step ... */ }
}

struct NoContentView: View {
    let imageName: String; let title: String; let message: String
    var body: some View { /* ... Implementation from previous step ... */ }
}

struct PostsGridView: View {
    let posts: [AudioPost] // Use REAL AudioPost
    let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)
    var body: some View { /* ... Implementation from previous step ... */ }
}

struct TabButton: View {
    let title: String; let isSelected: Bool; let action: () -> Void
    var body: some View { /* ... Implementation from previous step ... */ }
}

struct PostGridItem: View {
    let post: AudioPost // Use REAL AudioPost
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.1)).aspectRatio(1, contentMode: .fill)
                VStack(spacing: 4) {
                    Image(systemName: "waveform").font(.system(size: 30)).foregroundColor(.secondary.opacity(0.8))
                    // --- FIX: Assume duration is NON-OPTIONAL based on previous error ---
                    Text(formatDuration(post.duration)) // <-- Use directly
                        .font(.caption).foregroundColor(.secondary)
                    // --- If duration *IS* optional, use 'if let':
                    // if let duration = post.duration { Text(formatDuration(duration)).font(.caption)... }
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(post.title).font(.caption).fontWeight(.medium).lineLimit(1).foregroundColor(.primary)
                HStack {
                    Image(systemName: "play.circle")
                    // --- FIX: Assume plays is NON-OPTIONAL based on previous error ---
                    Text("\(post.plays)") // <-- Use directly
                    // --- If plays *IS* optional, use '??':
                    // Text("\(post.plays ?? 0)")
                }.font(.caption2).foregroundColor(.secondary)
            }
            .padding(.horizontal, 6).padding(.vertical, 6)
        }
        .background(Color(.systemBackground)).cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Edit Profile View
struct EditProfileView: View {
    @EnvironmentObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) var dismiss
    @State private var selectedPhotoItem: PhotosPickerItem? = nil

    var body: some View {
        NavigationView {
            Form {
                Section("Profile Picture") { /* ... Implementation using viewModel.selectedImage ... */ }
                Section("Details") {
                    // --- FIX: Ensure correct Binding usage ---
                    TextField("Name", text: $viewModel.name) // Use $viewModel
                    VStack(alignment: .leading) {
                        Text("Bio").font(.caption).foregroundColor(.gray)
                        TextEditor(text: $viewModel.bio) // Use $viewModel
                            .frame(height: 100).padding(-5)
                    }
                    // --- END FIX ---
                }
                if let errorMessage = viewModel.errorMessage { /* ... Error display ... */ }
            }
            .navigationTitle("Edit Profile").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel", role: .cancel) { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // --- FIX: Ensure Task and await are used ---
                        Task { if await viewModel.saveProfileChanges() { dismiss() } }
                        // --- END FIX ---
                    } label: {
                        if viewModel.isLoading { ProgressView().tint(.blue) } else { Text("Save").bold() }
                    }
                    .disabled(viewModel.isLoading || !viewModel.hasChanges)
                }
            }
            .task(id: selectedPhotoItem) { await viewModel.loadImageFromPickerItem(selectedPhotoItem) }
            .alert("Error Saving Profile", isPresented: $viewModel.showErrorAlert, presenting: viewModel.errorMessage) { _ in Button("OK") {} } message: { message in Text(message) }
        }
    }
}

// MARK: - Editable Profile Image Subview
struct EditableProfileImageView: View {
    let selectedImage: UIImage?; let profileImageURL: URL? // Use REAL UserProfile type
    var body: some View { /* ... Implementation from previous step ... */ }
}

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var authService: AuthenticationService; @Environment(\.dismiss) var dismiss
    var body: some View { /* ... Implementation from previous step ... */ }
}


// MARK: - Preview

// --- FIX: Remove placeholder AudioPostDetailView ---
// struct AudioPostDetailView: View { ... } // DELETE THIS LINE
// --- END FIX ---

// --- FIX: Remove placeholder AudioPostService ---
// class AudioPostService: ObservableObject { ... } // DELETE THIS CLASS (Use REAL one or a dedicated PREVIEW stub)
// --- END FIX ---

// Ensure REAL UserProfile has static preview or define here
// extension UserProfile { static var preview: UserProfile { ... } }

// Ensure REAL AudioPostService can be initialized for Preview or use a stub
class PreviewAudioPostService: AudioPostService { // Example Stub
     override init() { /* Need base init? */ super.init() } // Example
     override func fetchUserPosts(userId: String) { print("Preview Fetch") }
}

#Preview {
    let previewAuthService = AuthenticationService()
    let previewAudioPostService = PreviewAudioPostService() // Use REAL or Stub
    previewAuthService.userProfile = .preview // Use REAL UserProfile.preview
    // previewAudioPostService.userPosts = [...] // Add REAL AudioPost sample data

    // Pass services to the initializer
    return ProfileView(authService: previewAuthService, audioPostService: previewAudioPostService)
        .environmentObject(previewAuthService)
        .environmentObject(previewAudioPostService)
}
