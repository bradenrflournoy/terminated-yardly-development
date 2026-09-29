// MembershipRequestModel.swift

import Foundation
import FirebaseFirestore
#if canImport(FirebaseFirestoreSwift)
import FirebaseFirestoreSwift
#endif

struct MembershipRequestModel: Identifiable, Codable {
    @DocumentID var id: String?
    var businessID: String
    var userID: String
    var userName: String
    var status: String // "pending", "approved", "rejected"
    var timestamp: Date
}
