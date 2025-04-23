import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage // <-- Ensure this is uncommented if using updateUserProfile
import SwiftUI // For UIImage
import Combine
import GoogleSignIn
import GoogleSignInSwift // Needed for GIDSignInResult async/await

@MainActor
class AuthenticationService: ObservableObject {
    @Published var userProfile: UserProfile?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()
    private var authListenerHandle: AuthStateDidChangeListenerHandle?

    init() {
        setupAuthListener()
         print("AuthenticationService Initialized")
    }
    deinit {
        if let handle = authListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
         print("AuthenticationService Deinitialized")
    }

    // MARK: - Auth State Listening
    private func setupAuthListener() {
        authListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] (_, user) in
            Task { [weak self] in // Ensure async call happens within Task
                guard let self = self else { return } // Ensure self is valid on MainActor

                if let firebaseUser = user {
                    print("Auth Listener: User signed in (UID: \(firebaseUser.uid))")
                    // Optional delay might not be needed with async/await checks
                    // try? await Task.sleep(nanoseconds: 500_000_000)

                    if Auth.auth().currentUser?.uid == firebaseUser.uid {
                        do {
                            // Fetch profile when user signs in
                            try await self.fetchUserProfile(userId: firebaseUser.uid)
                            print("Auth Listener: Profile fetch successful for \(firebaseUser.uid).")
                        } catch {
                             print("Auth Listener: Profile fetch failed after sign-in for \(firebaseUser.uid): \(error)")
                             // Decide if an error message should be shown here
                             // self.errorMessage = "Failed to load profile after sign-in."
                             self.userProfile = nil // Ensure consistency
                             self.isLoading = false // Stop loading if fetch fails
                        }
                    } else {
                         print("Auth Listener: User changed before profile fetch could start.")
                         self.userProfile = nil
                         self.isLoading = false
                    }
                } else {
                    print("Auth Listener: User signed out")
                    // Clear profile and state on sign out
                    self.userProfile = nil
                    self.isLoading = false
                    self.errorMessage = nil
                }
            }
        }
    }

    // MARK: - Profile Fetching (Async)
    func fetchUserProfile(userId: String) async throws {
        guard Auth.auth().currentUser?.uid == userId else {
            print("fetchUserProfile: Aborting fetch. User \(userId) not authenticated.")
            self.userProfile = nil; self.isLoading = false
            throw NSError(domain: "AuthError", code: -101, userInfo: [NSLocalizedDescriptionKey: "User logged out before profile fetch."])
        }

        print("fetchUserProfile: Fetching profile for \(userId)...")
        self.isLoading = true; self.errorMessage = nil
        let docRef = Firestore.firestore().collection("users").document(userId)

        do {
            let document = try await docRef.getDocument()

            guard Auth.auth().currentUser?.uid == userId else {
                 print("fetchUserProfile: Aborting fetch. User \(userId) logged out during fetch.")
                 self.userProfile = nil; self.isLoading = false
                 throw NSError(domain: "AuthError", code: -102, userInfo: [NSLocalizedDescriptionKey: "User logged out during profile fetch."])
             }

            if document.exists {
                self.userProfile = try document.data(as: UserProfile.self)
                self.errorMessage = nil
                print("fetchUserProfile: Successfully fetched profile for \(userId)")
            } else {
                self.errorMessage = "User profile document not found."
                 print("fetchUserProfile: Document does not exist for \(userId)")
                self.userProfile = nil // Ensure profile is nil if document doesn't exist
            }
        } catch {
            self.errorMessage = "Failed to fetch/decode profile: \(error.localizedDescription)"
            print("fetchUserProfile: Error for \(userId): \(error)")
            self.userProfile = nil
            throw error // Re-throw so caller knows about the failure
        }
        self.isLoading = false // Stop loading after success or handled error
    }

    // MARK: - Google Sign-In (Async)
    func signInWithGoogle() async {
        self.isLoading = true; self.errorMessage = nil
        do {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                throw NSError(domain: "SignInError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not find root view controller."])
            }
            guard let clientID = FirebaseApp.app()?.options.clientID else {
                 throw NSError(domain: "SignInError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Firebase client ID not found."])
            }
            // let config = GIDConfiguration(clientID: clientID) // Assuming config set elsewhere
            let gidSignInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            guard let idTokenString = gidSignInResult.user.idToken?.tokenString else {
                 throw NSError(domain: "SignInError", code: -3, userInfo: [NSLocalizedDescriptionKey: "Google Sign-In ID token missing."])
            }
            let accessTokenString = gidSignInResult.user.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(withIDToken: idTokenString, accessToken: accessTokenString)
            let authResult = try await Auth.auth().signIn(with: credential)
             print("signInWithGoogle: Successfully signed into Firebase: \(authResult.user.uid)")
            try await checkAndCreateUserProfile(firebaseUser: authResult.user, googleUser: gidSignInResult.user)
             print("signInWithGoogle: Profile check/create complete for \(authResult.user.uid)")
            self.errorMessage = nil // Full success

        } catch let gidError as GIDSignInError where gidError.code == .canceled {
             print("Google Sign-In cancelled by user."); self.errorMessage = nil; self.isLoading = false // Clear loading on cancellation
        } catch {
            print("signInWithGoogle: Error: \(error)"); self.errorMessage = "Sign-In failed: \(error.localizedDescription)"; self.isLoading = false // Clear loading on error
        }
        // Note: isLoading = false on success path happens within checkAndCreateUserProfile
    }

    // MARK: - Profile Check/Create Helper (Async)
    private func checkAndCreateUserProfile(firebaseUser: FirebaseAuth.User, googleUser: GIDGoogleUser) async throws {
         print("checkAndCreateUserProfile: Checking profile for \(firebaseUser.uid)...")
         let userRef = Firestore.firestore().collection("users").document(firebaseUser.uid)

         do {
             guard Auth.auth().currentUser?.uid == firebaseUser.uid else {
                  print("checkAndCreateUserProfile: User changed before Firestore check. Aborting.")
                 throw NSError(domain: "AuthError", code: -103, userInfo: [NSLocalizedDescriptionKey: "User changed during sign in process"])
             }
             let document = try await userRef.getDocument()
             guard Auth.auth().currentUser?.uid == firebaseUser.uid else {
                  print("checkAndCreateUserProfile: User changed after Firestore check. Aborting.")
                 throw NSError(domain: "AuthError", code: -104, userInfo: [NSLocalizedDescriptionKey: "User changed during sign in process"])
             }

             if document.exists {
                 print("checkAndCreateUserProfile: Profile exists for \(firebaseUser.uid).")
                 // Profile exists, sign-in successful. Listener *should* fetch it.
                 // We can optionally manually fetch here too if listener timing is an issue.
                 // try await fetchUserProfile(userId: firebaseUser.uid) // Manual fetch if needed
                 self.isLoading = false // Sign-in process complete
             } else {
                 print("checkAndCreateUserProfile: Creating profile for \(firebaseUser.uid)...")
                 let imageURLString = googleUser.profile?.imageURL(withDimension: 200)?.absoluteString
                 let imageURL = imageURLString.flatMap { URL(string: $0) } // Create URL? from String?
                 let newProfile = UserProfile( // Ensure UserProfile init matches these params
                    id: firebaseUser.uid, // Assuming String? or String ID
                    username: createUsername(from: googleUser),
                    name: googleUser.profile?.name ?? "User",
                    email: googleUser.profile?.email ?? "",
                    bio: "",
                    profileImageURL: imageURL, // Pass URL?
                    followers: 0,
                    following: 0,
                    createdAt: Date() // Pass Date? or Date
                 )
                 try await userRef.setData(from: newProfile) // Save the new profile
                 guard Auth.auth().currentUser?.uid == firebaseUser.uid else {
                     print("checkAndCreateUserProfile: User changed after profile creation. State might be inconsistent.")
                     // Don't throw, just stop loading. Listener will handle the new user state.
                     self.isLoading = false
                     return // Exit early
                 }
                 print("checkAndCreateUserProfile: Profile created successfully for \(firebaseUser.uid).")
                 // Manually update local profile AFTER creation since listener might be delayed
                 self.userProfile = newProfile
                 self.errorMessage = nil
                 self.isLoading = false // Sign-in process complete
             }
         } catch {
             print("checkAndCreateUserProfile: Error for \(firebaseUser.uid): \(error)")
             self.errorMessage = "Failed to check/create profile: \(error.localizedDescription)"
             self.isLoading = false // Ensure loading stops on error
             // Should we sign the user out if profile check/create fails? Potentially.
             // self.signOut()
             throw error // Re-throw
         }
    }

    // MARK: - Username Creation Helper
    // --- FIX: Corrected createUsername to ensure return ---
    private func createUsername(from googleUser: GIDGoogleUser) -> String {
        if let email = googleUser.profile?.email {
            let parts = email.split(separator: "@")
            if let firstPart = parts.first {
                let baseUsername = String(firstPart).replacingOccurrences(of: "[^a-zA-Z0-9_]", with: "", options: .regularExpression)
                if !baseUsername.isEmpty {
                     return "\(baseUsername)\(Int.random(in: 100...999))" // <-- RETURN
                }
            }
        }
        // Fallback if email processing fails or email is nil
        print("createUsername: Could not generate username from email, using fallback.")
        return "user\(Int.random(in: 1000...9999))" // <-- FALLBACK RETURN
     }
     // --- END FIX ---

    // MARK: - Sign Out
    func signOut() {
        print("Attempting Sign Out...")
        GIDSignIn.sharedInstance.signOut() // Sign out from Google
        do {
            try Auth.auth().signOut() // Sign out from Firebase
            print("Sign Out Successful (Firebase).")
            // Auth listener handles clearing profile/state
        } catch {
            print("Error signing out from Firebase: \(error)")
            errorMessage = "Error signing out: \(error.localizedDescription)"
        }
    }

    // MARK: - Profile Updates (Ensure uncommented if needed)

    // Ensure this function signature matches calls from ViewModel
    func updateUserProfile(name: String, bio: String, profileImage: UIImage?) async throws -> UserProfile {
        guard let user = Auth.auth().currentUser else { throw NSError(domain: "AuthError", code: -105, userInfo: [NSLocalizedDescriptionKey: "User not authenticated for update."]) }
        // Consider adding a specific loading state for updates if needed
        // self.isUpdating = true
        print("updateUserProfile: Updating profile for \(user.uid)...")

        do {
            var updates: [String: Any] = ["name": name, "bio": bio, "updatedAt": FieldValue.serverTimestamp()]
            if let profileImage = profileImage {
                let imageURL = try await uploadProfileImage(image: profileImage, userId: user.uid)
                updates["profileImageURL"] = imageURL.absoluteString
            }
            // Handle image removal: else { updates["profileImageURL"] = FieldValue.delete() }

            try await updateUserDocument(userId: user.uid, updates: updates)
            try await fetchUserProfile(userId: user.uid) // Re-fetch to confirm and get latest data
            guard let updatedProfile = self.userProfile else { throw NSError(domain: "UpdateError", code: -106, userInfo: [NSLocalizedDescriptionKey: "Failed to get updated profile after save."]) }
            print("updateUserProfile: Update successful for \(user.uid).")
            // self.isUpdating = false
            return updatedProfile

        } catch {
            print("updateUserProfile: Error for \(user.uid): \(error)")
            // self.isUpdating = false
            throw error // Re-throw error
        }
    }

    private func updateUserDocument(userId: String, updates: [String: Any]) async throws {
         let docRef = Firestore.firestore().collection("users").document(userId)
         try await docRef.updateData(updates)
    }

    private func uploadProfileImage(image: UIImage, userId: String) async throws -> URL {
        guard let imageData = image.jpegData(compressionQuality: 0.6) else { throw NSError(domain: "ImageError", code: -107, userInfo: [NSLocalizedDescriptionKey: "Failed to process image"]) }
        let storageRef = Storage.storage().reference().child("profileImages/\(userId).jpg")
        print("uploadProfileImage: Uploading to \(storageRef.fullPath)...")
        do {
            // Use correct async methods from Firebase Storage SDK
            let _ = try await storageRef.putDataAsync(imageData) // Check if this method exists
            let downloadURL = try await storageRef.downloadURL() // Check if this method exists
            print("uploadProfileImage: Upload success. URL: \(downloadURL)")
            return downloadURL
        } catch {
            print("uploadProfileImage: Storage Error: \(error)"); throw error
        }
    }

} // End of class AuthenticationService
