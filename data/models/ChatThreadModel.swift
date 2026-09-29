// ChatThreadModel.swift

import FirebaseFirestore
#if canImport(FirebaseFirestoreSwift)
import FirebaseFirestoreSwift
#endif
import Foundation

struct ChatThreadModel: Identifiable, Codable {
    @DocumentID var id: String?                 // threadID (e.g., userA_userB)
    var participants: [String]                  // [user1ID, user2ID]
    var lastMessage: String                     // Last message text (or placeholder for image)
    var lastMessageTimestamp: Date              // For sorting in MessagesScreen
    var lastSenderID: String                    // Who sent the last message
    var unreadCounts: [String: Int] // keyed by userID
}
