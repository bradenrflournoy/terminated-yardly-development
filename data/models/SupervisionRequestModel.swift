// SupervisionRequestModel.swift

import Foundation
import FirebaseFirestore
#if canImport(FirebaseFirestoreSwift)
import FirebaseFirestoreSwift
#endif

struct SupervisionRequestModel: Codable, Identifiable {
    @DocumentID var id: String? = nil
    var businessID: String
    var supervisorID: String
    var supervisorName: String
    var status: String // "pending", "approved", "rejected"
    var timestamp: Date
}
