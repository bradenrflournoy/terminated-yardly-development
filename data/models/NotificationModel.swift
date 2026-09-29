// NotificationModel.swift

import Foundation
import FirebaseFirestore
#if canImport(FirebaseFirestoreSwift)
import FirebaseFirestoreSwift
#endif

struct NotificationModel: Identifiable, Codable {
    @DocumentID var id: String?
    var userID: String
    var title: String
    var message: String
    var timestamp: Date
    var read: Bool
}
