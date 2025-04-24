//
//  OiOiApp.swift
//  OiOi
//
//  Created by Merid Berhe on 10.04.2025.
//

import SwiftUI
import Firebase

// --- AppDelegate for Firebase Configuration ---
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
         print("Firebase Configured in AppDelegate")
        // Initialize other AppDelegate-level services if needed
        return true
    }
    // Add other AppDelegate methods if needed (e.g., push notifications)
}

// --- Main App Structure ---
@main
struct OiOiApp: App {
    // Connect AppDelegate
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    // --- Create shared service instances with @StateObject ---
    // These live for the duration of the App
    @StateObject private var authService = AuthenticationService()
    @StateObject private var audioRecorder = AudioRecorderService()
    @StateObject private var audioPostService = AudioPostService()

    var body: some Scene {
        WindowGroup {
            // --- Root View Logic: Show Login or Main App ---
            // Checks authentication status to determine the initial view
            if authService.userProfile != nil {
                // User is logged in, show the main tab view
                MainTabView()
                    // --- Inject services into the environment for MainTabView and its children ---
                    .environmentObject(authService)
                    .environmentObject(audioRecorder)
                    .environmentObject(audioPostService)
            } else {
                // User is not logged in, show the login view
                LoginView()
                    // --- Inject only necessary services for LoginView ---
                    .environmentObject(authService)
            }
        }
    }
}

// --- Main Tab Container View ---
struct MainTabView: View {
    // --- Receive services from the environment ---
    // These are populated by the .environmentObject modifiers in OiOiApp
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var audioRecorder: AudioRecorderService
    @EnvironmentObject var audioPostService: AudioPostService

    var body: some View {
        TabView {
            // --- Feed Tab ---
            NavigationView {
                FeedView() // Assumes FeedView uses @EnvironmentObject if needed
            }
            .tabItem { Label("Feed", systemImage: "house.fill") }
            // Ensure FeedView can access services via @EnvironmentObject

            // --- Channels Tab ---
            NavigationView {
                ChannelsView() // Assumes ChannelsView uses @EnvironmentObject if needed
            }
            .tabItem { Label("Channels", systemImage: "square.grid.2x2.fill") }

            // --- Record Tab ---
            NavigationView {
                // RecordView will automatically receive services via @EnvironmentObject
                // because MainTabView has them in its environment.
                RecordView()
            }
            .tabItem { Label("Record", systemImage: "mic.circle.fill") }

            // --- Profile Tab ---
            NavigationView {
                // ProfileView uses initializer injection here, which is also valid.
                // It receives the instances that MainTabView got from the environment.
                ProfileView(authService: authService, audioPostService: audioPostService)
            }
            .tabItem { Label("Profile", systemImage: "person.fill") }
        }
        // No need for further .environmentObject modifiers here; they are inherited
    }
}

// Note: Ensure FeedView, ChannelsView, LoginView, ProfileView,
// and the service classes (AuthenticationService, etc.) are defined elsewhere in your project.
