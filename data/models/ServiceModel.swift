// ServiceModel.swift

import Foundation
import FirebaseFirestore
#if canImport(FirebaseFirestoreSwift)
import FirebaseFirestoreSwift
#endif

struct ServiceModel: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var title: String
    var description: String
    var price: Double
    var businessID: String // owner business
    var timestamp: Date = Date()
    var bookingsCount: Int? = 0
    var imageURL: String?
    var category: String? // e.g., "Lawncare", "Snow", "Cleanup"
}
