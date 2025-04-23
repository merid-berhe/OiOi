import Foundation
import AVFoundation
import SwiftUI
import Combine

enum AudioRecorderError: Error {
    case permissionDenied
    case setupFailed
    case recordingFailed
}

class AudioRecorderService: NSObject, ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    private var audioEngine: AVAudioEngine?
    private var audioPlayer: AVAudioPlayer?
    
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var audioLevel: Float = 0.0
    @Published var recordedFileURL: URL?
    
    private var timer: Timer?
    
    override init() {
        super.init()
        do {
            try setupAudioSession()
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    private func setupAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default)
        try session.setActive(true)
    }
    
    private func requestPermission() async throws {
        if #available(iOS 17.0, *) {
            let granted = await AVAudioApplication.requestRecordPermission()
            guard granted else {
                throw AudioRecorderError.permissionDenied
            }
        } else {
            let granted = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
            guard granted else {
                throw AudioRecorderError.permissionDenied
            }
        }
    }
    
    func startRecording() async throws {
        try await requestPermission()
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("\(UUID().uuidString).m4a")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            
            isRecording = true
            recordedFileURL = audioFilename
            
            startMonitoring()
        } catch {
            throw AudioRecorderError.recordingFailed
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        recordingTime = 0
        // Keep the recordedFileURL
    }
    
    func resetRecording() {
        stopRecording() // Stop if currently recording
        recordedFileURL = nil
        recordingTime = 0
        audioLevel = 0
    }
    
    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.audioRecorder?.updateMeters()
            self.audioLevel = self.audioRecorder?.averagePower(forChannel: 0) ?? 0.0
            self.recordingTime = self.audioRecorder?.currentTime ?? 0.0
        }
    }
    
    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    func playRecording() {
        guard let url = recordedFileURL else { return }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            print("Failed to play recording: \(error)")
        }
    }
}

extension AudioRecorderService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        isRecording = false
        stopMonitoring()
        if !flag {
            recordedFileURL = nil
        }
    }
} 