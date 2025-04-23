//
//  OiOiApp.swift
//  OiOi
//
//  Created by Merid Berhe on 10.04.2025.
//

import SwiftUI
import Firebase

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
         print("Firebase Configured in AppDelegate")
        return true
    }
}

@main
struct OiOiApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authService = AuthenticationService()
    @StateObject private var audioRecorder = AudioRecorderService()
    @StateObject private var audioPostService = AudioPostService()

    var body: some Scene {
        WindowGroup {
            if authService.userProfile != nil {
                MainTabView()
                    .environmentObject(authService)
                    .environmentObject(audioRecorder)
                    .environmentObject(audioPostService)
            } else {
                LoginView()
                    .environmentObject(authService)
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var audioRecorder: AudioRecorderService
    @EnvironmentObject var audioPostService: AudioPostService

    var body: some View {
        TabView {
            // --- Feed Tab ---
            // Assumes FeedView is defined elsewhere
            NavigationView {
                FeedView()
                    // Pass services if needed by FeedView
                    // .environmentObject(audioPostService)
                    // .environmentObject(authService)
            }
            .tabItem { Label("Feed", systemImage: "house.fill") }

            // --- Channels Tab ---
            // Assumes ChannelsView is defined elsewhere
            NavigationView {
                ChannelsView()
            }
            .tabItem { Label("Channels", systemImage: "square.grid.2x2.fill") }

            // --- Record Tab ---
            // Assumes RecordView is defined elsewhere
            NavigationView {
                RecordView()
                    // Pass services if needed by RecordView
                    // .environmentObject(authService)
                    // .environmentObject(audioRecorder)
                    // .environmentObject(audioPostService)
            }
            .tabItem { Label("Record", systemImage: "mic.circle.fill") }

            // --- Profile Tab ---
            // ProfileView uses the initializer we defined
            NavigationView {
                ProfileView(authService: authService, audioPostService: audioPostService)
            }
            .tabItem { Label("Profile", systemImage: "person.fill") }
        }
    }
}

// --- FIX: REMOVE PLACEHOLDER DEFINITIONS ---
// struct FeedView: View { var body: some View { Text("Feed View") } } // DELETE THIS
// struct ChannelsView: View { var body: some View { Text("Channels View") } } // DELETE THIS
// struct RecordView: View { var body: some View { Text("Record View") } } // DELETE THIS
// --- END FIX ---

// Ensure LoginView is defined elsewhere
// Ensure AuthenticationService, AudioPostService, AudioRecorderService are defined elsewhere

