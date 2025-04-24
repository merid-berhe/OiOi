import Foundation
import AVFoundation
import SwiftUI
import Combine

enum AudioRecorderError: Error {
    case permissionDenied
    case setupFailed
    case recordingFailed
    case playbackFailed(Error)
}

class AudioRecorderService: NSObject, ObservableObject, AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?

    // Recording State
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var audioLevel: Float = 0.0
    @Published var recordedFileURL: URL?

    // Playback State
    @Published var isPlaying = false
    @Published var playbackTime: TimeInterval = 0 // Time elapsed during playback
    @Published var playbackDuration: TimeInterval = 0 // Total duration of the recorded file for playback

    private var recordingTimer: Timer?
    private var playbackTimer: Timer?

    // --- Initialization and Session Setup ---

    override init() {
        super.init()
        do {
            try setupAudioSession()
        } catch {
            print("Failed to set up audio session: \(error)")
            // Consider publishing an error state for the UI
        }
    }

    private func setupAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        // Ensure category allows playback even when silent switch is on / background audio
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)
    }

    // --- Permissions ---

    private func requestPermission() async throws {
        if #available(iOS 17.0, *) {
            let granted = await AVAudioApplication.requestRecordPermission()
            guard granted else { throw AudioRecorderError.permissionDenied }
        } else {
            let granted = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
            guard granted else { throw AudioRecorderError.permissionDenied }
        }
    }

    // --- Recording Logic ---

    func startRecording() async throws {
        // Ensure clean state before starting
        if isPlaying { stopPlayback() }
        if isRecording { stopRecording() } // Stop previous recording if any

        try await requestPermission()

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1, // Mono recording
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = nil // Ensure previous instance is released
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true

            if audioRecorder?.record() == true {
                DispatchQueue.main.async {
                    self.isRecording = true
                    self.recordedFileURL = audioFilename
                    self.recordingTime = 0
                    self.audioLevel = 0
                    self.playbackTime = 0 // Reset playback time as well
                    self.playbackDuration = 0 // Reset playback duration
                }
                startRecordingMonitoring()
            } else {
                print("AudioRecorder failed to start recording.")
                throw AudioRecorderError.recordingFailed
            }
        } catch {
            print("Failed to initialize or start AVAudioRecorder: \(error)")
            DispatchQueue.main.async { // Ensure UI updates if start fails
                self.isRecording = false
                self.recordedFileURL = nil
            }
            throw AudioRecorderError.setupFailed
        }
    }

    func stopRecording() {
        guard audioRecorder?.isRecording == true else { return }
        print("Stopping recording...")
        audioRecorder?.stop()
        // Delegate (audioRecorderDidFinishRecording) will handle state updates
    }

    func resetRecording() {
        print("Resetting recording...")
        if isRecording { stopRecording() }
        if isPlaying { stopPlayback() }

        // Delete the file
        if let url = recordedFileURL {
            do {
                try FileManager.default.removeItem(at: url)
                print("Deleted recording file: \(url.lastPathComponent)")
            } catch {
                print("Error deleting recording file: \(error)")
            }
        }

        // Reset state
        DispatchQueue.main.async {
             self.recordedFileURL = nil
             self.recordingTime = 0
             self.audioLevel = 0
             self.playbackTime = 0
             self.playbackDuration = 0
             self.isRecording = false // Ensure this is false
             self.isPlaying = false // Ensure this is false
        }
    }

    private func startRecordingMonitoring() {
        recordingTimer?.invalidate() // Ensure no duplicate timers
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let recorder = self.audioRecorder, recorder.isRecording else {
                // Invalidate timer if recorder becomes nil or stops unexpectedly
                self?.stopRecordingMonitoring()
                return
            }
            recorder.updateMeters()
            let averagePower = recorder.averagePower(forChannel: 0)
            let normalizedLevel = max(0.0, min(1.0, (160.0 + averagePower) / 160.0)) // Simple linear scale (0-1)

            // Update on main thread
            DispatchQueue.main.async {
                self.audioLevel = normalizedLevel
                self.recordingTime = recorder.currentTime
            }
        }
    }

    private func stopRecordingMonitoring() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        DispatchQueue.main.async {
            self.audioLevel = 0.0 // Reset level visually
        }
    }

    // --- Playback Logic ---

    func togglePlayback() {
        guard let url = recordedFileURL else {
            print("No recording file URL found to play.")
            return
        }

        if isRecording { stopRecording() } // Should ideally wait for delegate confirmation

        if isPlaying {
            // Pause playback
            audioPlayer?.pause()
            stopPlaybackMonitoring()
            DispatchQueue.main.async { self.isPlaying = false }
        } else {
            // Start or resume playback
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.defaultToSpeaker, .allowBluetooth]) // Switch category for playback
                try AVAudioSession.sharedInstance().setActive(true)

                // If player exists, URL matches, just resume
                if let player = audioPlayer, player.url == url {
                    player.play()
                } else {
                    // Setup new player
                    audioPlayer = try AVAudioPlayer(contentsOf: url)
                    audioPlayer?.delegate = self
                    // Set duration here for progress UI
                    let duration = audioPlayer?.duration ?? 0
                    DispatchQueue.main.async { self.playbackDuration = duration }
                    audioPlayer?.play()
                }

                startPlaybackMonitoring()
                DispatchQueue.main.async { self.isPlaying = true }

            } catch {
                print("Failed to play recording: \(error)")
                DispatchQueue.main.async {
                    self.isPlaying = false
                    self.playbackTime = 0
                    self.playbackDuration = 0
                    // Consider publishing an error state AudioRecorderError.playbackFailed(error)
                }
            }
        }
    }

    func stopPlayback() {
        guard audioPlayer != nil else { return }
        print("Stopping playback...")
        audioPlayer?.stop() // Stops playback and resets player's currentTime to 0
        stopPlaybackMonitoring()
        DispatchQueue.main.async {
            self.isPlaying = false
            self.playbackTime = 0 // Explicitly reset time
            // playbackDuration remains as the file's duration
        }
        // Optionally switch audio session back if needed immediately elsewhere
        // try? setupAudioSession() // Or handle category switching more granularly
    }

    // --- Playback Progress Monitoring ---

    private func startPlaybackMonitoring() {
        playbackTimer?.invalidate() // Ensure no duplicate timers
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
             guard let self = self, let player = self.audioPlayer, player.isPlaying else {
                 // Invalidate timer if player becomes nil or stops playing
                 self?.stopPlaybackMonitoring()
                 // Could also check here if player.currentTime >= player.duration and stop monitoring
                 return
             }
             // Update playback time on main thread
             DispatchQueue.main.async {
                 self.playbackTime = player.currentTime
             }
        }
    }

    private func stopPlaybackMonitoring() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }


    // MARK: - AVAudioRecorderDelegate

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        let finalTime = recorder.currentTime
        print("audioRecorderDidFinishRecording - Success: \(flag), Time: \(finalTime)")
        DispatchQueue.main.async {
            self.isRecording = false
            self.recordingTime = finalTime // Set accurate final time
            self.stopRecordingMonitoring() // Stop updating levels/time from recording

            if !flag {
                print("Recording finished unsuccessfully.")
                self.recordedFileURL = nil // Clear URL if failed
                self.playbackDuration = 0 // Reset duration too
                // Consider publishing an error state
            } else {
                print("Recording finished successfully at URL: \(self.recordedFileURL?.absoluteString ?? "nil")")
                // Pre-load duration for playback UI if needed immediately after recording
                if let url = self.recordedFileURL {
                     do {
                          let tempPlayer = try AVAudioPlayer(contentsOf: url)
                          self.playbackDuration = tempPlayer.duration
                     } catch {
                          print("Could not preload duration after recording: \(error)")
                          self.playbackDuration = 0
                     }
                }
            }
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("Audio recorder encode error: \(error?.localizedDescription ?? "Unknown error")")
        DispatchQueue.main.async {
            self.isRecording = false
            self.stopRecordingMonitoring()
            self.recordedFileURL = nil
            self.playbackDuration = 0
            // Consider publishing an error state
        }
    }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("audioPlayerDidFinishPlaying - Success: \(flag)")
        DispatchQueue.main.async {
            self.isPlaying = false
            self.playbackTime = flag ? self.playbackDuration : 0 // Set to end or reset based on success
            self.stopPlaybackMonitoring()
        }
         // Switch audio session back to playAndRecord if desired after playback finishes
         // try? setupAudioSession()
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Audio player decode error: \(error?.localizedDescription ?? "Unknown error")")
        DispatchQueue.main.async {
            self.isPlaying = false
            self.playbackTime = 0
            self.stopPlaybackMonitoring()
            // Consider publishing an error state AudioRecorderError.playbackFailed(error ?? NSError())
        }
    }
}
