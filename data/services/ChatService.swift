// ChatService.swift

import FirebaseFirestore
#if canImport(FirebaseFirestoreSwift)
import FirebaseFirestoreSwift
#endif

class ChatService {
    private let db = Firestore.firestore()
    
    // MARK: - Threads
    func streamThreads(for userID: String, completion: @escaping ([ChatThreadModel]) -> Void) -> ListenerRegistration {
        db.collection("chatThreads")
            .whereField("participants", arrayContains: userID)
            .addSnapshotListener { snapshot, error in
                guard let docs = snapshot?.documents else { return }
                let threads = docs.compactMap { try? $0.data(as: ChatThreadModel.self) }
                completion(threads)
            }
    }
    
    func updateThread(threadID: String, lastMessage: String, senderID: String, participants: [String]) async throws {
        let data: [String: Any] = [
            "participants": participants,
            "lastMessage": lastMessage.isEmpty ? "[Image]" : lastMessage,
            "lastMessageTimestamp": FieldValue.serverTimestamp(),
            "lastSenderID": senderID
        ]
        try await db.collection("chatThreads").document(threadID).setData(data, merge: true)
    }
    
    func markThreadAsRead(threadID: String, userID: String) async throws {
        let threadRef = db.collection("chatThreads").document(threadID)
        try await threadRef.updateData(["unreadCounts.\(userID)": 0])
    }
    
    // MARK: - Messages
    func streamMessages(for threadID: String, completion: @escaping ([MessageModel]) -> Void) -> ListenerRegistration {
        db.collection("messages")
            .whereField("chatThreadID", isEqualTo: threadID)
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { snapshot, error in
                guard let docs = snapshot?.documents else { return }
                completion(docs.compactMap { try? $0.data(as: MessageModel.self) })
            }
    }
    
    func loadMessages(threadID: String, limit: Int = 20, startAfter: DocumentSnapshot? = nil) async throws -> ([MessageModel], DocumentSnapshot?) {
        var query: Query = db.collection("messages")
            .whereField("chatThreadID", isEqualTo: threadID)
            .order(by: "timestamp", descending: false)

        if let start = startAfter {
            // Pagination in ascending order
            query = query.start(afterDocument: start).limit(to: limit)
        } else {
            // First page: get the last N in ascending order
            query = query.limit(toLast: limit)
        }

        let snapshot = try await query.getDocuments()
        let messages = snapshot.documents.compactMap { try? $0.data(as: MessageModel.self) }
        let lastDoc = snapshot.documents.last
        return (messages, lastDoc)
    }
    
    func sendMessage(_ message: MessageModel) async throws {
        _ = try db.collection("messages").addDocument(from: message)
    }
}
