// MessageModel.swift

import Foundation
import FirebaseFirestore
#if canImport(FirebaseFirestoreSwift)
import FirebaseFirestoreSwift
#endif

enum MessageStatus: String, Codable {
    case sent
    case read
}

struct MessageModel: Identifiable, Codable {
    @DocumentID var id: String?
    var senderID: String
    var recipientID: String
    var text: String
    var timestamp: Date
    var firstResponseAt: Date?
    var chatThreadID: String
    var imageURL: String?
    var status: MessageStatus
}
