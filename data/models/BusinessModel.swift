// BusinessModel.swift

import Foundation
import FirebaseFirestore
#if canImport(FirebaseFirestoreSwift)
import FirebaseFirestoreSwift
#endif
import CoreLocation

enum BusinessType: String, Codable {
    case individual
    case organization
}

struct AvailabilitySlot: Codable {
    var day: String // e.g. "Monday"
    var timeRanges: [String] // e.g. "9am-12pm"
}

struct BusinessModel: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var businessName: String
    var businessType: BusinessType
    var managerID: String
    var memberIDs: [String]
    var supervisorID: String?
    var bio: String
    var profileImageURL: String?
    var availability: [AvailabilitySlot] = []
    var activeJobIDs: [String] = []
    var completedJobIDs: [String] = []
    var cancellationCount: Int = 0
    var lastLateJob: Date?
    var repeatClientRate: Double?
    var level: Int
    var badges: [String]?
    var timeZone: String
    var latitude: Double?
    var longitude: Double?
    var joinDate: Date?
    var isStaffPicked: Bool?
    var featuredInBlog: Bool?
    var ecoFriendly: Bool
    var petFriendly: Bool
    var familyOwned: Bool
    var businessCode: String
    var hasCompletedOnboarding: Bool

    // Keep as computed — doesn't affect Hashable/Equatable
    var location: CLLocation? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocation(latitude: lat, longitude: lon)
    }

    // MARK: - Hashable & Equatable
    static func == (lhs: BusinessModel, rhs: BusinessModel) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
