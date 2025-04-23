import Foundation
import Firebase
import FirebaseFirestore
import FirebaseStorage
import Combine
import AVFoundation
import FirebaseAuth

class AudioPostService: ObservableObject {
    @Published var posts = [AudioPost]()
    @Published var trendingPosts = [AudioPost]()
    @Published var userPosts = [AudioPost]()
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    private var postsListener: ListenerRegistration?
    
    init() {
        fetchPosts()
    }
    
    deinit {
        postsListener?.remove()
    }
    
    // MARK: - Fetch Methods
    
    func fetchPosts() {
        isLoading = true
        errorMessage = nil
        
        postsListener = db.collection("posts")
            .order(by: "createdAt", descending: true)
            .limit(to: 20)
            .addSnapshotListener { [weak self] (querySnapshot, error) in
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    print("Error fetching posts: \(error)")
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    self?.errorMessage = "No posts found"
                    return
                }
                
                self?.posts = documents.compactMap { document -> AudioPost? in
                    do {
                        let post = try document.data(as: AudioPost.self)
                        return post
                    } catch {
                        print("Error decoding post: \(error)")
                        return nil
                    }
                }
                
                self?.fetchTrendingPosts()
            }
    }
    
    func fetchTrendingPosts() {
        db.collection("posts")
            .order(by: "likes", descending: true)
            .limit(to: 10)
            .getDocuments { [weak self] (querySnapshot, error) in
                if let error = error {
                    print("Error fetching trending posts: \(error)")
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    return
                }
                
                self?.trendingPosts = documents.compactMap { document -> AudioPost? in
                    do {
                        let post = try document.data(as: AudioPost.self)
                        return post
                    } catch {
                        print("Error decoding trending post: \(error)")
                        return nil
                    }
                }
            }
    }
    
    func fetchUserPosts(userId: String) {
        isLoading = true
        errorMessage = nil
        
        db.collection("posts")
            .whereField("authorId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments { [weak self] (querySnapshot, error) in
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    print("Error fetching user posts: \(error)")
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    self?.userPosts = []
                    return
                }
                
                self?.userPosts = documents.compactMap { document -> AudioPost? in
                    do {
                        let post = try document.data(as: AudioPost.self)
                        return post
                    } catch {
                        print("Error decoding user post: \(error)")
                        return nil
                    }
                }
            }
    }
    
    // MARK: - Actions
    
    func likePost(_ post: AudioPost) {
        guard let postId = post.id, Auth.auth().currentUser?.uid != nil else {
            print("Error: Post ID or User ID missing.")
            return
        }

        let postRef = db.collection("posts").document(postId)
        let incrementValue = post.isLiked ? -1 : 1

        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let postDocument: DocumentSnapshot
            do {
                try postDocument = transaction.getDocument(postRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }

            let currentLikes = postDocument.data()?["likes"] as? Int ?? 0
            let newLikes = max(0, currentLikes + incrementValue)

            transaction.updateData(["likes": newLikes], forDocument: postRef)
            return nil
        }) { [weak self] (object, error) in
            if let error = error {
                self?.errorMessage = "Like update failed: \(error.localizedDescription)"
                print("Transaction failed: \(error)")
            } else {
                print("Transaction successfully committed!")
            }
        }
    }
    
    func incrementPlays(_ post: AudioPost) {
        guard let postId = post.id else { return }
        
        db.collection("posts").document(postId).updateData([
            "plays": FieldValue.increment(Int64(1))
        ])
    }
    
    // MARK: - Upload
    
    func uploadAudioPost(title: String, description: String?, audioFileURL: URL, duration: TimeInterval, tags: [String]) -> AnyPublisher<AudioPost, Error> {
        return Future<AudioPost, Error> { [weak self] promise in
            guard let self = self else {
                promise(.failure(NSError(domain: "AudioPostService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Service not available"])))
                return
            }
            
            guard let user = Auth.auth().currentUser,
                  let authorName = user.displayName,
                  let authorUsername = user.email?.components(separatedBy: "@").first
            else {
                promise(.failure(NSError(domain: "AudioPostService", code: 1, userInfo: [NSLocalizedDescriptionKey: "User profile information incomplete"])))
                return
            }
            
            self.isLoading = true
            self.errorMessage = nil
            
            // 1. Upload audio file to storage
            let audioFileName = "\(UUID().uuidString).m4a"
            let storageRef = Storage.storage().reference().child("audio/\(audioFileName)")
            
            let uploadTask = storageRef.putFile(from: audioFileURL, metadata: nil) { (metadata, error) in
                if let error = error {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                    promise(.failure(error))
                    return
                }
                
                // 2. Get download URL
                storageRef.downloadURL { (url, error) in
                    if let error = error {
                        self.isLoading = false
                        self.errorMessage = error.localizedDescription
                        promise(.failure(error))
                        return
                    }
                    
                    guard let downloadURL = url else {
                        self.isLoading = false
                        let error = NSError(domain: "AudioPostService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL"])
                        self.errorMessage = error.localizedDescription
                        promise(.failure(error))
                        return
                    }
                    
                    // 3. Create audio post in Firestore
                    let post = AudioPost(
                        title: title,
                        description: description,
                        audioURL: downloadURL,
                        authorId: user.uid,
                        authorName: authorName,
                        authorUsername: authorUsername,
                        authorProfileImageURL: user.photoURL,
                        createdAt: Date(),
                        duration: duration,
                        likes: 0,
                        plays: 0,
                        comments: 0,
                        tags: tags,
                        isLiked: false
                    )
                    
                    do {
                        let docRef = try self.db.collection("posts").addDocument(from: post)
                        self.isLoading = false
                        
                        // 4. Fetch the created post with its ID
                        docRef.getDocument { (document, error) in
                            if let error = error {
                                self.errorMessage = error.localizedDescription
                                promise(.failure(error))
                                return
                            }
                            
                            guard let document = document, let createdPost = try? document.data(as: AudioPost.self) else {
                                let error = NSError(domain: "AudioPostService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch created post"])
                                self.errorMessage = error.localizedDescription
                                promise(.failure(error))
                                return
                            }
                            
                            promise(.success(createdPost))
                        }
                    } catch {
                        self.isLoading = false
                        self.errorMessage = error.localizedDescription
                        promise(.failure(error))
                    }
                }
            }
            
            uploadTask.observe(.progress) { snapshot in
                let progress = Double(snapshot.progress?.completedUnitCount ?? 0) / Double(snapshot.progress?.totalUnitCount ?? 1)
                print("Upload progress: \(progress * 100)%")
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    // MARK: - Helpers
    
    private func getCurrentUsername() -> String? {
        // This is a fallback if displayName is not set
        guard let userId = Auth.auth().currentUser?.uid else { return nil }
        
        var username: String?
        let semaphore = DispatchSemaphore(value: 0)
        
        db.collection("users").document(userId).getDocument { (document, error) in
            if let document = document, document.exists {
                username = document.data()?["username"] as? String
            }
            semaphore.signal()
        }
        
        _ = semaphore.wait(timeout: .now() + 2.0)
        return username
    }
} 