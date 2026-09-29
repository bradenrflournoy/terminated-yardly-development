// BookingModel.swift

import Foundation
import FirebaseFirestore
#if canImport(FirebaseFirestoreSwift)
import FirebaseFirestoreSwift
#endif

enum BookingStatus: String, Codable {
    case scheduled
    case inProgress
    case completed
    case cancelled
    case pendingApproval
}

struct BookingModel: Identifiable, Codable {
    @DocumentID var id: String?
    var homeownerID: String
    var businessID: String
    var service: ServiceModel
    var date: Date
    var timeSlot: String?
    var isRecurring: Bool
    var recurringIntervalWeeks: Int?
    var status: BookingStatus
    var requiresApproval: Bool = false
    var isApproved: Bool = false
    var timeZone: String
    var latitude: Double?
    var longitude: Double?
    var locationDescription: String?
}
