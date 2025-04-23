import SwiftUI
import AVFoundation

struct AudioPostDetailView: View {
    @StateObject private var viewModel: AudioPostViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var showingReportSheet = false
    @State private var showingShareSheet = false
    @State private var showingComments = false
    @State private var commentText = ""
    
    init(post: AudioPost) {
        _viewModel = StateObject(wrappedValue: AudioPostViewModel(audioPost: post))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 12) {
                    if let authorProfileImage = viewModel.audioPost.authorProfileImageURL {
                        AsyncImage(url: authorProfileImage) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.blue)
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.audioPost.authorName)
                            .font(.headline)
                        
                        Text("@\(viewModel.audioPost.authorUsername)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        showingReportSheet = true
                    }) {
                        Image(systemName: "ellipsis")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
                // Title and Description
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.audioPost.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let description = viewModel.audioPost.description, !description.isEmpty {
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Tags
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(viewModel.audioPost.tags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(16)
                            }
                        }
                    }
                    
                    Text(viewModel.formatDate(viewModel.audioPost.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding(.horizontal)
                
                // Audio Player
                VStack {
                    ZStack {
                        Rectangle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(height: 200)
                            .cornerRadius(12)
                        
                        VStack {
                            // Waveform visualization (placeholder)
                            HStack(spacing: 4) {
                                ForEach(0..<30, id: \.self) { i in
                                    Rectangle()
                                        .fill(Color.blue.opacity(0.5))
                                        .frame(width: 3, height: CGFloat.random(in: 10...80))
                                        .cornerRadius(1.5)
                                }
                            }
                            .frame(height: 100)
                            
                            // Player controls
                            HStack {
                                Text(viewModel.formatTime(viewModel.currentTime))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Slider(value: Binding(
                                    get: { viewModel.currentTime },
                                    set: { viewModel.seekTo(time: $0) }
                                ), in: 0...max(viewModel.audioPost.duration, 0.01))
                                .accentColor(.blue)
                                
                                Text(viewModel.formatTime(viewModel.audioPost.duration))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Play/Pause button
                            Button(action: viewModel.togglePlayPause) {
                                Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding()
                    }
                    .padding(.horizontal)
                    
                    // Stats and interaction buttons
                    HStack(spacing: 24) {
                        // Play count
                        HStack {
                            Image(systemName: "headphones")
                            Text("\(viewModel.audioPost.plays)")
                        }
                        .foregroundColor(.secondary)
                        
                        // Like button
                        Button(action: viewModel.toggleLike) {
                            HStack {
                                Image(systemName: viewModel.isLiked ? "heart.fill" : "heart")
                                    .foregroundColor(viewModel.isLiked ? .red : .secondary)
                                Text("\(viewModel.audioPost.likes)")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Comment button
                        Button(action: { showingComments = true }) {
                            HStack {
                                Image(systemName: "text.bubble")
                                Text("\(viewModel.audioPost.comments)")
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        // Share button
                        Button(action: { showingShareSheet = true }) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .font(.subheadline)
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                
                // Comments section
                if showingComments {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Comments")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        // Add comment field
                        HStack {
                            TextField("Add a comment...", text: $commentText)
                                .padding(10)
                                .background(Color(.systemGray6))
                                .cornerRadius(20)
                            
                            Button(action: {
                                viewModel.addComment(text: commentText)
                                commentText = ""
                            }) {
                                Text("Post")
                                    .foregroundColor(.blue)
                                    .fontWeight(.semibold)
                            }
                            .disabled(commentText.isEmpty)
                        }
                        .padding(.horizontal)
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // Comment list
                        if viewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else if viewModel.comments.isEmpty {
                            Text("No comments yet. Be the first to comment!")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else {
                            ForEach(viewModel.comments) { comment in
                                CommentRow(comment: comment)
                            }
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingReportSheet) {
            ReportView(post: viewModel.audioPost)
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = viewModel.audioPost.audioURL {
                ShareSheet(items: [url])
            }
        }
        .onDisappear {
            viewModel.pauseAudio()
        }
        .alert(item: Binding(
            get: {
                if let error = viewModel.errorMessage { return ViewError(message: error) }
                return nil
            },
            set: { _ in viewModel.errorMessage = nil }
        )) { error in
            Alert(title: Text("Error"), message: Text(error.message), dismissButton: .default(Text("OK")))
        }
    }
}

struct ViewError: Identifiable {
    var id = UUID()
    var message: String
}

struct CommentRow: View {
    let comment: Comment
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let profileImageURL = comment.authorProfileImageURL {
                AsyncImage(url: profileImageURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.blue)
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(comment.authorName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("• \(RelativeDateTimeFormatter().localizedString(for: comment.createdAt, relativeTo: Date()))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(comment.text)
                    .font(.subheadline)
                
                HStack {
                    Button(action: {}) {
                        HStack {
                            Image(systemName: comment.isLiked ? "heart.fill" : "heart")
                                .foregroundColor(comment.isLiked ? .red : .secondary)
                            Text("\(comment.likes)")
                                .foregroundColor(.secondary)
                        }
                        .font(.caption)
                    }
                    
                    Spacer()
                }
                .padding(.top, 4)
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ReportView: View {
    let post: AudioPost
    @Environment(\.dismiss) var dismiss
    @State private var reportReason = ""
    @State private var showingConfirmation = false
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Report this post")
                    .font(.headline)
                    .padding(.top)
                
                Text("Please tell us why you're reporting this post.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 12) {
                    ReportOption(title: "Inappropriate content", isSelected: reportReason == "Inappropriate content") {
                        reportReason = "Inappropriate content"
                    }
                    
                    ReportOption(title: "Spam", isSelected: reportReason == "Spam") {
                        reportReason = "Spam"
                    }
                    
                    ReportOption(title: "Harassment", isSelected: reportReason == "Harassment") {
                        reportReason = "Harassment"
                    }
                    
                    ReportOption(title: "Copyright infringement", isSelected: reportReason == "Copyright infringement") {
                        reportReason = "Copyright infringement"
                    }
                    
                    ReportOption(title: "Other", isSelected: reportReason == "Other") {
                        reportReason = "Other"
                    }
                }
                
                Spacer()
                
                Button(action: {
                    showingConfirmation = true
                }) {
                    Text("Submit Report")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(reportReason.isEmpty ? Color.gray : Color.red)
                        .cornerRadius(10)
                }
                .disabled(reportReason.isEmpty)
                .padding(.bottom)
            }
            .padding()
            .navigationBarItems(trailing: Button("Cancel") {
                dismiss()
            })
            .alert(isPresented: $showingConfirmation) {
                Alert(
                    title: Text("Report Submitted"),
                    message: Text("Thank you for your report. We'll review this post as soon as possible."),
                    dismissButton: .default(Text("OK")) {
                        dismiss()
                    }
                )
            }
        }
    }
}

struct ReportOption: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

#Preview {
    NavigationView {
        AudioPostDetailView(post: AudioPost.previewPost)
    }
} 