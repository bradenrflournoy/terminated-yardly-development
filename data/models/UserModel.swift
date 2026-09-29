// UserModel.swift

import Foundation
import FirebaseFirestore
#if canImport(FirebaseFirestoreSwift)
import FirebaseFirestoreSwift
#endif

enum UserRole: String, Codable, CaseIterable {
    case teen, homeowner, supervisor
}

struct UserModel: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var email: String
    var name: String
    var profileImageURL: String?
    var role: UserRole
    var recentSearches: [String] = []
    var jobHistoryIDs: [String] = []
    var businessID: String?
    var bio: String?
    var phoneNumber: String?
    var supervisedBusinessIDs: [String]?
    var onboardingComplete: Bool
    var pendingBusinessMembership: Bool? // optional for compatibility
}
