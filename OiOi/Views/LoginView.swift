// LoginView.swift
import SwiftUI
import Combine // Keep Combine if other parts of your app use it, otherwise optional

struct LoginView: View {
    @EnvironmentObject var authService: AuthenticationService
    // Removed @State variables for email, password, username, isSignUp, showingAlert, alertMessage
    // Removed cancellables as they were only used for the old email/password publishers

    var body: some View {
        VStack(spacing: 30) { // Increased spacing a bit
            Spacer() // Push content down

            // Logo / Title
            VStack(spacing: 10) {
                Text("OiOi")
                    .font(.system(size: 50, weight: .bold)) // Made title larger
                    .foregroundColor(.blue)

                Text("Share your voice")
                    .font(.title3) // Adjusted subtitle font
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 50) // Added more space below title


            // Loading Indicator
            if authService.isLoading {
                ProgressView()
                    .scaleEffect(1.5) // Make indicator larger
                    .padding(.vertical, 20) // Add padding around indicator
            }

            // Error Message Display
            if let errorMessage = authService.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.callout) // Slightly larger error font
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity) // Allow text to wrap
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
            }

            Spacer() // Pushes button and errors towards center/bottom

            // --- Google Sign-In Button ---
            Button {
                // --- FIX: Wrap async call in a Task ---
                Task {
                    await authService.signInWithGoogle()
                    // Since authService is @MainActor, UI updates
                    // (isLoading = false, userProfile updated) will happen
                    // automatically on the main thread after this await finishes.
                }
                // --- END FIX ---
            } label: {
                HStack {
                    // You NEED to add a "google_logo" image to your Assets.xcassets
                    // Or remove this Image view if you don't have one
                    Image("google_logo") // Make sure this asset exists!
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22) // Slightly larger logo

                    Text("Sign in with Google")
                        .fontWeight(.semibold) // Slightly bolder text
                        .font(.title3) // Match subtitle font size
                }
                .padding(.vertical, 12) // Adjust padding
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground)) // Use system background for better light/dark mode adaptation
                .foregroundColor(Color(.label)) // Use label color for better adaptation
                .cornerRadius(10) // Consistent corner radius
                // Adding a subtle border can look good too
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                )
                // Removed shadow, border often looks cleaner
            }
            .padding(.horizontal) // Padding for the button itself

            Spacer() // Add spacer at the bottom
             Spacer() // Add more spacer to push button up a bit from bottom edge

        }
        .padding() // Padding for the whole VStack
        // Removed NavigationView wrapper as it might not be needed for a simple login screen
        // Removed ScrollView as content is less likely to overflow now
    }

    // Removed handleAuth, login, signUp private functions
}

// Updated Preview Provider
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        // Example with no error
        LoginView()
            .environmentObject(AuthenticationService()) // Provide a dummy service

        // Example showing error message
        LoginView()
            .environmentObject(createAuthServiceWithError())

        // Example showing loading indicator
        LoginView()
            .environmentObject(createAuthServiceLoading())
    }

    // Helper functions for previews
    static func createAuthServiceWithError() -> AuthenticationService {
        let service = AuthenticationService()
        service.errorMessage = "Something went wrong during sign in. Please try again."
        return service
    }

    static func createAuthServiceLoading() -> AuthenticationService {
        let service = AuthenticationService()
        service.isLoading = true
        return service
    }
}
