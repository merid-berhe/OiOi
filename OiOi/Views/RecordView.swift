import SwiftUI
import Combine
import AVFoundation

struct RecordView: View {
    @EnvironmentObject var audioRecorder: AudioRecorderService
    @EnvironmentObject var authService: AuthenticationService
    
    @StateObject private var viewModel: RecordViewModel
    
    init() {
        let recorder = AudioRecorderService()
        let postService = AudioPostService()
        let auth = AuthenticationService()
        
        _viewModel = StateObject(wrappedValue: RecordViewModel(
            audioRecorder: recorder,
            audioPostService: postService,
            authService: auth
        ))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.1))
                        .frame(height: 200)
                    
                    VStack {
                        if audioRecorder.isRecording {
                            HStack(alignment: .bottom, spacing: 4) {
                                ForEach(0..<20) { _ in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.blue)
                                        .frame(width: 4, height: CGFloat.random(in: 10...100))
                                        .animation(.easeInOut(duration: 0.2), value: audioRecorder.audioLevel)
                                }
                            }
                        } else {
                            Image(systemName: "waveform")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                        }
                        
                        Text(formatTime(audioRecorder.recordingTime))
                            .font(.title)
                            .foregroundColor(.blue)
                            .padding(.top)
                    }
                }
                
                HStack(spacing: 40) {
                    Button(action: {
                        audioRecorder.stopRecording()
                        audioRecorder.recordedFileURL = nil
                    }) {
                        Image(systemName: "trash")
                            .font(.title)
                            .foregroundColor(.red)
                    }
                    .opacity(audioRecorder.recordedFileURL != nil ? 1 : 0)
                    
                    Button(action: {
                        if audioRecorder.isRecording {
                            audioRecorder.stopRecording()
                        } else {
                            Task {
                                try await audioRecorder.startRecording()
                            }
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 80, height: 80)
                            
                            if audioRecorder.isRecording {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white)
                                    .frame(width: 30, height: 30)
                            } else {
                                Circle()
                                    .stroke(Color.white, lineWidth: 4)
                                    .frame(width: 30, height: 30)
                            }
                        }
                    }
                    
                    Button(action: {
                        audioRecorder.playRecording()
                    }) {
                        Image(systemName: "play.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                    }
                    .opacity(audioRecorder.recordedFileURL != nil ? 1 : 0)
                }
                .padding()
                
                if audioRecorder.recordedFileURL != nil {
                    VStack(spacing: 16) {
                        TextField("Title", text: $viewModel.title)
                            .textFieldStyle(.roundedBorder)
                        
                        TextField("Description (optional)", text: $viewModel.description)
                            .textFieldStyle(.roundedBorder)
                        
                        TextField("Tags (comma separated)", text: $viewModel.tags)
                            .textFieldStyle(.roundedBorder)
                        
                        if viewModel.isUploading {
                            ProgressView("Uploading...")
                                .padding()
                        } else {
                            Button(action: { viewModel.publishPost() }) {
                                Text("Publish")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(viewModel.isFormValid ? Color.blue : Color.blue.opacity(0.5))
                                    .cornerRadius(12)
                            }
                            .disabled(!viewModel.isFormValid || viewModel.isUploading)
                        }
                    }
                    .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Record")
            .alert(isPresented: $viewModel.showingAlert) {
                Alert(
                    title: Text(viewModel.alertTitle),
                    message: Text(viewModel.alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct ChannelPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedChannel: Channel?
    
    var body: some View {
        NavigationView {
            List(Channel.defaultChannels) { channel in
                Button(action: {
                    selectedChannel = channel
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: channel.iconName)
                            .foregroundColor(channel.isNSFW ? .red : .blue)
                        Text(channel.name)
                        Spacer()
                        if selectedChannel?.id == channel.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Select Channel")
            .navigationBarItems(trailing: Button("Cancel") {
                dismiss()
            })
        }
    }
}

struct PublishConfirmationView: View {
    @Environment(\.dismiss) var dismiss
    let audioURL: URL
    let title: String
    let description: String
    let tags: [String]
    let channel: Channel
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Ready to publish?")
                    .font(.title)                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: channel.iconName)
                        Text(channel.name)
                    }
                    .font(.headline)
                    
                    Text(title)
                        .font(.title3)
                    
                    if !description.isEmpty {
                        Text(description)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        ForEach(tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Button(action: {
                    dismiss()
                }) {
                    Text("Publish Now")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                
                Spacer()
            }
            .padding()
            .navigationBarItems(trailing: Button("Cancel") {
                dismiss()
            })
        }
    }
}

#Preview {
    RecordView()
        .environmentObject(AudioRecorderService())
        .environmentObject(AuthenticationService())
} 
