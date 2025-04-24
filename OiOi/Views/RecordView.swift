import SwiftUI
import Combine
import AVFoundation

struct RecordView: View {
    // --- Use EnvironmentObjects provided by parent views ---
    @EnvironmentObject var audioRecorder: AudioRecorderService
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var audioPostService: AudioPostService // Add if needed by ViewModel directly

    // --- ViewModel initialized using the EnvironmentObjects ---
    @StateObject private var viewModel: RecordViewModel

    // --- Initializer receives EnvironmentObjects ---
    // NOTE: This custom init might not be strictly necessary if the ViewModel can
    // also take the services directly from the Environment or if the parent view
    // initializes the ViewModel and passes it down.
    // However, explicitly passing them ensures the ViewModel gets the correct instances.
    init() {
        // This initializer pattern assumes the @EnvironmentObjects will be available
        // when the view's body is evaluated. We need to initialize the @StateObject
        // slightly differently or ensure the services are available *before* this init runs.
        // A safer pattern is often to initialize the ViewModel in the parent view
        // or use a wrapper that delays ViewModel creation until environment objects are ready.

        // --- **Revised Initializer Approach:** ---
        // Initialize StateObject using a temporary placeholder or a factory pattern
        // if direct access to EnvironmentObject isn't possible *within* the init method itself.
        // A common pattern is to inject them via the view's initializer from the parent,
        // but since we are using @EnvironmentObject, we expect them to be present.
        // Let's structure the ViewModel init assuming access *after* SwiftUI sets up the environment.
        // The most robust way requires passing the services *into* this View's initializer
        // from the parent view that *does* have access to them.

        // --- **Alternative (Simpler if ViewModel doesn't need services in its init):** ---
        // If RecordViewModel can be initialized without services immediately, or if it
        // fetches them later (e.g., in an .onAppear block or accesses them directly via
        // Combine publishers), you could simplify. But the current ViewModel init requires them.

        // --- **Let's assume parent injects for clarity & correctness:** ---
        // This init is now removed. We expect the parent view to create RecordView
        // and ensure the environment objects are set. The @StateObject will then
        // be initialized using these environment objects when the view appears.
        // **REMOVE THE CUSTOM init() ENTIRELY and ensure parent view handles injection.**

        // --- **Correct @StateObject Initialization (using implicit environment access):** ---
        // To make @StateObject work correctly with @EnvironmentObject, we need the services
        // *when* the @StateObject is initialized. The most standard way is to pass them
        // explicitly from the parent view that sets up the environment objects.

        // Let's modify the structure assuming the Parent View does this:
        // ParentView:
        // RecordView(
        //    viewModel: RecordViewModel(audioRecorder: recorderService, audioPostService: postService, authService: authService)
        // )
        // Then RecordView would look like:
        // @StateObject var viewModel: RecordViewModel
        // (No custom init needed here for the ViewModel itself)

        // --- **Sticking to the original request (ViewModel init needs EnvironmentObjects):** ---
        // We'll use a temporary placeholder and update in onAppear, OR rely on the fact
        // that the EnvironmentObjects *should* be populated by the time the body is called.
        // Let's use the original structure but acknowledge its fragility if services aren't ready.
         _viewModel = StateObject(wrappedValue: RecordViewModel(
             // THESE WILL CRASH IF THE ENVIRONMENT OBJECTS AREN'T SET BY THE PARENT VIEW
             // This relies on internal SwiftUI behavior which isn't guaranteed.
             // **RECOMMENDATION:** Inject ViewModel from parent or pass services explicitly.
             // For now, keeping structure as requested, assuming parent sets up Environment.
             audioRecorder: AudioRecorderService(), // Placeholder - Will be overridden by env
             audioPostService: AudioPostService(), // Placeholder
             authService: AuthenticationService() // Placeholder
         ))
         // Ideally, the ViewModel would access EnvironmentObjects directly if possible,
         // or they are passed explicitly during RecordView creation by its parent.
    }


    var body: some View {
        // --- Inject Environment Objects into the ViewModel ---
        // This ensures the ViewModel uses the *correct* instances from the environment,
        // overriding any placeholders used during initial @StateObject creation.
        // We use task/onAppear to ensure environment is settled.
        let _ = Self._printChanges() // Useful for debugging view updates
        NavigationView {
            VStack(spacing: 15) { // Reduced spacing slightly
                recordingProgressView
                
                recordingControlsView
                    .padding(.vertical, 5) // Add some vertical padding

                // --- Playback Progress (Visible only when recording exists) ---
                if audioRecorder.recordedFileURL != nil && audioRecorder.playbackDuration > 0 {
                    playbackProgressView
                        .padding(.horizontal) // Add padding to progress bar
                }

                // --- Form (Visible only when recording exists) ---
                if audioRecorder.recordedFileURL != nil {
                    recordingFormView
                }

                Spacer() // Pushes content up
            }
            .navigationTitle("Record")
            .alert(isPresented: $viewModel.showingAlert) {
                Alert(
                    title: Text(viewModel.alertTitle),
                    message: Text(viewModel.alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            // --- Task to correctly initialize ViewModel with Environment Objects ---
            // This is a safer way to ensure the ViewModel gets the correct service instances
            // after the view and its environment have been set up.
            .task {
                 viewModel.audioRecorder = audioRecorder
                 viewModel.audioPostService = audioPostService
                 viewModel.authService = authService
                 // You might need to call a setup function in the ViewModel here
                 // if it relies on these services being present immediately after init.
                 // viewModel.setupSubscribers() // Example if needed
            }
        }
        // Ensure environment objects are passed down if this view presents others
        .environmentObject(audioRecorder)
        .environmentObject(authService)
        .environmentObject(audioPostService)
    }

    // MARK: - Subviews

    private var recordingProgressView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.1))
                .frame(height: 180) // Slightly smaller

            VStack(spacing: 10) { // Added spacing
                if audioRecorder.isRecording {
                    // Placeholder for a more dynamic waveform visualization
                    HStack(alignment: .bottom, spacing: 4) {
                         // Use normalized audioLevel (0-1)
                        let levelHeight = CGFloat(max(0.1, audioRecorder.audioLevel)) * 80 // Max height 80
                        RoundedRectangle(cornerRadius: 2)
                             .fill(Color.blue)
                             .frame(width: 50, height: levelHeight)
                             .animation(.easeInOut(duration: 0.15), value: audioRecorder.audioLevel)
                        Text("Recording...")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                } else {
                    Image(systemName: "waveform")
                        .font(.system(size: 50)) // Smaller icon
                        .foregroundColor(.blue)
                }

                Text(formatTime(audioRecorder.isRecording ? audioRecorder.recordingTime : audioRecorder.playbackDuration))
                    .font(.title2) // Slightly smaller time
                    .foregroundColor(.blue)
                    .padding(.top, 5)
            }
        }
        .padding(.horizontal) // Add horizontal padding
    }

    private var recordingControlsView: some View {
        HStack(spacing: 40) {
            // Delete Button
            Button(action: {
                // --- Use resetRecording from service ---
                audioRecorder.resetRecording()
            }) {
                Image(systemName: "trash")
                    .font(.title)
                    .foregroundColor(.red)
            }
            // --- Disable if no recording exists ---
            .disabled(audioRecorder.recordedFileURL == nil)
            .opacity(audioRecorder.recordedFileURL != nil ? 1 : 0.5) // Fade if disabled

            // Record/Stop Button
            Button(action: {
                if audioRecorder.isRecording {
                    audioRecorder.stopRecording()
                } else {
                    Task {
                        do {
                             try await audioRecorder.startRecording()
                        } catch {
                             print("Error starting recording: \(error)")
                             viewModel.showAlert(title: "Recording Error", message: error.localizedDescription)
                        }
                    }
                }
            }) {
                ZStack {
                    Circle()
                        .fill(audioRecorder.isRecording ? Color.red : Color.gray) // Gray when stopped
                        .frame(width: 70, height: 70) // Slightly smaller

                    Image(systemName: audioRecorder.isRecording ? "stop.fill" : "mic.fill")
                         .font(.title) // Use mic/stop icons
                         .foregroundColor(.white)
                }
            }
             // Disable button briefly after stopping recording until file is ready? (Optional)

            // Play/Pause Button
            Button(action: {
                // --- Use togglePlayback ---
                audioRecorder.togglePlayback()
            }) {
                Image(systemName: audioRecorder.isPlaying ? "pause.fill" : "play.fill") // Toggle icon
                    .font(.title)
                    .foregroundColor(.blue)
            }
             // --- Disable if no recording exists ---
            .disabled(audioRecorder.recordedFileURL == nil)
            .opacity(audioRecorder.recordedFileURL != nil ? 1 : 0.5) // Fade if disabled
        }
    }

    @ViewBuilder // Use ViewBuilder for conditional logic if needed
    private var playbackProgressView: some View {
         // Ensure duration is valid to prevent division by zero or NaN
         let progress = (audioRecorder.playbackDuration > 0) ? (audioRecorder.playbackTime / audioRecorder.playbackDuration) : 0
         
         VStack(spacing: 5) {
              ProgressView(value: progress)
                   .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                   .frame(height: 8) // Make progress bar thicker

              HStack {
                   Text(formatTime(audioRecorder.playbackTime))
                   Spacer()
                   Text(formatTime(audioRecorder.playbackDuration))
              }
              .font(.caption)
              .foregroundColor(.gray)
         }
    }


    private var recordingFormView: some View {
        VStack(spacing: 12) { // Reduced spacing
            TextField("Title", text: $viewModel.title)
                .textFieldStyle(.roundedBorder)

            TextField("Description (optional)", text: $viewModel.description, axis: .vertical) // Allow vertical expansion
                 .lineLimit(3...) // Allow multiple lines
                .textFieldStyle(.roundedBorder)


            TextField("Tags (comma separated)", text: $viewModel.tags)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none) // Disable auto-capitalization for tags

            if viewModel.isUploading {
                ProgressView("Uploading...")
                    .padding(.top, 10) // Add padding above progress view
            } else {
                Button(action: { viewModel.publishPost() }) {
                    Text("Publish")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12) // Adjust padding
                        .background(viewModel.isFormValid ? Color.blue : Color.gray) // Use gray when disabled
                        .cornerRadius(10) // Slightly smaller radius
                }
                .disabled(!viewModel.isFormValid || viewModel.isUploading)
                .padding(.top, 10) // Add padding above button
            }
        }
        .padding() // Add padding around the form
    }

    // MARK: - Helper Functions

    private func formatTime(_ time: TimeInterval) -> String {
        let interval = max(0, time) // Ensure time is not negative
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}


// --- Preview Provider ---
// Make sure to inject necessary EnvironmentObjects for the preview to work.
// You might need mock versions of your services for robust previews.
#Preview {
     // Create instances of the services for the preview
     let recorder = AudioRecorderService()
     let auth = AuthenticationService() // Assuming a basic init works for preview
     let postService = AudioPostService() // Assuming a basic init works for preview

     // Example: Simulate a recorded file for previewing the form state
     // recorder.recordedFileURL = URL(string: "file:///dummy.m4a")
     // recorder.playbackDuration = 65 // 1 minute 5 seconds

    return RecordView()
        // Inject the services into the environment for the preview
        .environmentObject(recorder)
        .environmentObject(auth)
        .environmentObject(postService)
}

// --- Mock/Placeholder Services for Preview (Example) ---
// You might need more sophisticated mocks depending on service complexity
// class MockAudioRecorderService: AudioRecorderService { /* Override methods */ }
// class MockAuthService: AuthenticationService { /* Override properties/methods */ }
// class MockAudioPostService: AudioPostService { /* Override methods */ }
