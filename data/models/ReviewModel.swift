// ReviewModel.swift

import Foundation
import FirebaseFirestore
#if canImport(FirebaseFirestoreSwift)
import FirebaseFirestoreSwift
#endif

struct ReviewModel: Identifiable, Codable {
    @DocumentID var id: String?
    var reviewerID: String
    var businessID: String
    var rating: Int // 1 to 5
    var communicationRating: Int // private
    var comment: String
    var timestamp: Date
}
