// AuthViewModel.swift

import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import SwiftUI
import CoreLocation

@MainActor
class AuthViewModel: ObservableObject {
    @Published var currentUser: UserModel?
    @Published var isLoading: Bool = true
    
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private let firestoreService = FirestoreService()

    init() {
        Task {
            await checkAuthStatus()
        }
    }

    func checkAuthStatus() async {
        if let uid = Auth.auth().currentUser?.uid {
            do {
                try await fetchUser(uid: uid)
            } catch {
                print("Failed to fetch user: \(error)")
                currentUser = nil
            }
        }
        isLoading = false
    }

    func signIn(email: String, password: String) async throws {
        isLoading = true
        let result = try await auth.signIn(withEmail: email, password: password)
        try await fetchUser(uid: result.user.uid)
        isLoading = false
    }

    func signUp(email: String, password: String, name: String) async throws {
        isLoading = true
        let result = try await auth.createUser(withEmail: email, password: password)

        let newUser = UserModel(
            id: result.user.uid,
            email: email,
            name: name,
            profileImageURL: nil,
            role: .homeowner,
            recentSearches: [],
            jobHistoryIDs: [],
            businessID: nil,
            phoneNumber: nil,
            supervisedBusinessIDs: nil,
            onboardingComplete: false,
            pendingBusinessMembership: false
        )

        try db.collection("users").document(result.user.uid).setData(from: newUser)
        self.currentUser = newUser
        isLoading = false
    }

    func uploadProfileImage(_ image: UIImage) async throws -> String {
        guard let uid = auth.currentUser?.uid,
              let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw URLError(.badURL)
        }

        let ref = storage.reference().child("profileImages/\(uid).jpg")
        _ = try await ref.putDataAsync(imageData)
        return try await ref.downloadURL().absoluteString
    }

    func setupBusinessProfile(url: String?, bio: String, businessName: String?, ecoFriendly: Bool, petFriendly: Bool, familyOwned: Bool) async throws {
        guard var user = currentUser else { return }

        user.profileImageURL = url

        try await db.collection("users").document(user.id!).updateData([
            "profileImageURL": url ?? NSNull()
        ])

        if user.role == .teen {
            let locationManager = CLLocationManager()
            locationManager.requestWhenInUseAuthorization()
            let location = locationManager.location

            let newBusiness = BusinessModel(
                id: nil,
                businessName: businessName ?? "",
                businessType: .individual,
                managerID: user.id!,
                memberIDs: [user.id!],
                supervisorID: nil,
                bio: bio,
                profileImageURL: url,
                availability: [],
                activeJobIDs: [],
                completedJobIDs: [],
                cancellationCount: 0,
                lastLateJob: nil,
                repeatClientRate: 0.0,
                level: 0,
                badges: [],
                timeZone: TimeZone.current.identifier,
                latitude: location?.coordinate.latitude,
                longitude: location?.coordinate.longitude,
                joinDate: Date(),
                isStaffPicked: false,
                featuredInBlog: false,
                ecoFriendly: ecoFriendly,
                petFriendly: petFriendly,
                familyOwned: familyOwned,
                businessCode: UUID().uuidString.prefix(6).uppercased(),
                hasCompletedOnboarding: false
            )

            let ref = try db.collection("businesses").addDocument(from: newBusiness)
            try await db.collection("users").document(user.id!).updateData([
                "businessID": ref.documentID
            ])
            user.businessID = ref.documentID
            await firestoreService.updateBusinessLevelAndBadges(businessID: ref.documentID)

            try await db.collection("businesses").document(ref.documentID).updateData([
                "hasCompletedOnboarding": true
            ])
        }

        user.onboardingComplete = true
        try await db.collection("users").document(user.id!).updateData([
            "onboardingComplete": true
        ])
        currentUser = user

        if let bid = user.businessID {
            try? await db.collection("businesses").document(bid).updateData([
                "hasCompletedOnboarding": true
            ])
        }
    }

    func fetchUser(uid: String) async throws {
        let snapshot = try await db.collection("users").document(uid).getDocument()
        currentUser = try snapshot.data(as: UserModel.self)
    }
    
    func refreshCurrentUser() async throws {
        let uid = Auth.auth().currentUser?.uid
        guard let uid else { return }

        let doc = try await Firestore.firestore().collection("users").document(uid).getDocument()

        if !doc.exists {
            // Log out or redirect to sign-up
            try signOut()
            return
        }

        let user = try doc.data(as: UserModel.self)
        DispatchQueue.main.async {
            self.currentUser = user
        }
    }

    func signOut() throws {
        try auth.signOut()
        currentUser = nil
    }

    func updateEmail(_ newEmail: String) async throws {
        guard let user = auth.currentUser else { throw URLError(.userAuthenticationRequired) }

        try await user.updateEmail(to: newEmail)

        if let userID = user.uid as String? {
            try await db.collection("users").document(userID).updateData([
                "email": newEmail
            ])
            currentUser?.email = newEmail
        }
    }

    func updatePassword(_ newPassword: String) async throws {
        guard let user = auth.currentUser else { throw URLError(.userAuthenticationRequired) }

        try await user.updatePassword(to: newPassword)
    }

    func reauthenticate(currentPassword: String) async throws {
        guard let user = auth.currentUser, let email = user.email else {
            throw URLError(.userAuthenticationRequired)
        }

        let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
        try await user.reauthenticate(with: credential)
    }

    func updateUserProfile(_ user: UserModel) async throws {
        guard let userID = user.id else { return }
        try db.collection("users").document(userID).setData(from: user, merge: true)
    }
    
    func updateUserProfile(url: String?, bio: String) async throws {
        guard let userID = currentUser?.id else { return }

        try await db.collection("users").document(userID).updateData([
            "profileImageURL": url ?? NSNull(),
            "bio": bio
        ])

        currentUser?.profileImageURL = url
        currentUser?.bio = bio
    }
    
    func updateUserRole(to role: UserRole) async {
        guard let uid = currentUser?.id else { return }

        // Decide value for supervisedBusinessIDs
        let supervisedField: Any? = (role == .supervisor) ? [] : NSNull()

        do {
            let userRef = Firestore.firestore().collection("users").document(uid)
            
            try await userRef.updateData([
                "role": role.rawValue,
                "supervisedBusinessIDs": supervisedField as Any
            ])
            
            // Update locally too
            currentUser?.role = role
            currentUser?.supervisedBusinessIDs = (role == .supervisor) ? [] : nil
        } catch {
            print("Error updating role: \(error.localizedDescription)")
        }
    }
}
