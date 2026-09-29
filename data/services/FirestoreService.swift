// FirestoreService.swift

import Foundation
import FirebaseFirestore
#if canImport(FirebaseFirestoreSwift)
import FirebaseFirestoreSwift
#endif
import FirebaseStorage

class FirestoreService {
    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    func fetchServices() async throws -> [ServiceModel] {
        let snapshot = try await db.collection("services").getDocuments()
        return try snapshot.documents.map { try $0.data(as: ServiceModel.self) }
    }

    func fetchBusinesses() async throws -> [BusinessModel] {
        let snapshot = try await db.collection("businesses").getDocuments()
        return try snapshot.documents.map { try $0.data(as: BusinessModel.self) }
    }

    func createService(_ service: ServiceModel) async throws {
        _ = try db.collection("services").addDocument(from: service)
    }

    func updateService(_ service: ServiceModel, id: String) async throws {
        try db.collection("services").document(id).setData(from: service, merge: true)
    }

    func deleteService(id: String) async throws {
        try await db.collection("services").document(id).delete()
    }

    func bookService(_ booking: BookingModel) async throws {
        // Add the booking to the bookings collection
        let _ = try db.collection("bookings").addDocument(from: booking)

        // Increment the bookingsCount for the associated service
        if let serviceID = booking.service.id {
            let serviceRef = db.collection("services").document(serviceID)
            try await serviceRef.updateData([
                "bookingsCount": FieldValue.increment(Int64(1))
            ])
        }

        // Notify all members of the business (manager + team)
        let businessDoc = try await db.collection("businesses").document(booking.businessID).getDocument()
        if let business = try? businessDoc.data(as: BusinessModel.self) {
            let recipients = [business.managerID] + (business.memberIDs )
            for userID in recipients {
                NotificationManager.shared.notifyBookingConfirmed(
                    businessMemberID: userID,
                    serviceTitle: booking.service.title
                )
            }
        }
    }

    func checkDuplicateBooking(userID: String, serviceID: String, date: Date) async throws -> Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date

        let snapshot = try await db.collection("bookings")
            .whereField("homeownerID", isEqualTo: userID)
            .whereField("service.id", isEqualTo: serviceID)
            .whereField("date", isGreaterThanOrEqualTo: startOfDay)
            .whereField("date", isLessThan: endOfDay)
            .getDocuments()

        return !snapshot.documents.isEmpty
    }

    func updateBookingStatus(id: String, to status: BookingStatus) async throws {
        // Only apply lock if trying to cancel
        if status == .cancelled {
            let bookingRef = db.collection("bookings").document(id)
            let snapshot = try await bookingRef.getDocument()

            guard let booking = try? snapshot.data(as: BookingModel.self) else {
                throw NSError(domain: "InvalidBooking", code: 404, userInfo: [NSLocalizedDescriptionKey: "Booking not found."])
            }

            var calendar = Calendar.current
            if let tz = TimeZone(identifier: booking.timeZone) {
                calendar.timeZone = tz
            }
            let now = Date()
            let hours = calendar.dateComponents([.hour], from: now, to: booking.date).hour ?? 0
            if hours < 48 {
                throw NSError(domain: "BookingLocked", code: 403, userInfo: [NSLocalizedDescriptionKey: "This booking can no longer be cancelled."])
            }
        }

        // Proceed with update
        try await db.collection("bookings").document(id).updateData([
            "status": status.rawValue
        ])

        if status == .cancelled {
            // Fetch the booking to get the service ID for decrement
            let snapshot = try await db.collection("bookings").document(id).getDocument()
            if let booking = try? snapshot.data(as: BookingModel.self), let serviceID = booking.service.id {
                await decrementServiceBookingCount(serviceID: serviceID)
            }
        }
    }

    func leaveReview(_ review: ReviewModel) async throws {
        _ = try db.collection("reviews").addDocument(from: review)
    }

    func sendMessage(_ message: MessageModel) async throws {
        _ = try db.collection("messages").addDocument(from: message)
    }

    func fetchMessages(forThreadID threadID: String) async throws -> [MessageModel] {
        let snapshot = try await db.collection("messages")
            .whereField("chatThreadID", isEqualTo: threadID)
            .order(by: "timestamp", descending: false)
            .getDocuments()

        return try snapshot.documents.compactMap { doc in
            try doc.data(as: MessageModel.self)
        }
    }

    func streamMessages(forThreadID threadID: String, completion: @escaping ([MessageModel]) -> Void) -> ListenerRegistration {
        return db.collection("messages")
            .whereField("chatThreadID", isEqualTo: threadID)
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }

                let messages: [MessageModel] = documents.compactMap {
                    try? $0.data(as: MessageModel.self)
                }
                completion(messages)
            }
    }

    func uploadImage(_ data: Data, fileName: String) async throws -> String {
        let ref = storage.reference().child("chat_images/\(fileName)")
        let _ = try await ref.putDataAsync(data, metadata: nil)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    func updateMessageStatus(id: String, status: MessageStatus) async throws {
        try await db.collection("messages").document(id).updateData([
            "status": status.rawValue
        ])
    }
    
    func updateUserProfile(_ user: UserModel) async throws {
        guard let userID = user.id else { return }

        let updateData: [String: Any] = [
            "name": user.name,
            "bio": user.bio ?? "",
            "profileImageURL": user.profileImageURL ?? "",
            "phoneNumber": user.phoneNumber ?? "",
            "email": user.email
        ]

        try await db.collection("users").document(userID).updateData(updateData)
    }
    
    func fetchNotifications(for userID: String) async throws -> [NotificationModel] {
        let snapshot = try await db.collection("notifications")
            .whereField("userID", isEqualTo: userID)
            .order(by: "timestamp", descending: true)
            .getDocuments()
        
        return snapshot.documents.compactMap { try? $0.data(as: NotificationModel.self) }
    }
    
    func fetchBookingsForBusiness(businessID: String) async throws -> [BookingModel] {
        let snapshot = try await Firestore.firestore()
            .collection("bookings")
            .whereField("businessID", isEqualTo: businessID)
            .getDocuments()

        return snapshot.documents.compactMap { try? $0.data(as: BookingModel.self) }
    }
    
    func calculateAverageRating(for businessID: String) async throws -> Double {
        let snapshot = try await Firestore.firestore()
            .collection("reviews")
            .whereField("businessID", isEqualTo: businessID)
            .getDocuments()

        let ratings = snapshot.documents.compactMap { doc -> Double? in
            return doc.data()["rating"] as? Double
        }

        guard !ratings.isEmpty else { return 0.0 }

        let total = ratings.reduce(0.0, +)
        return total / Double(ratings.count)
    }
    
    func fetchUser(byID id: String) async throws -> UserModel {
        let snapshot = try await Firestore.firestore().collection("users").document(id).getDocument()
        return try snapshot.data(as: UserModel.self)
    }
    
    func fetchBusinessByID(_ businessID: String) async throws -> BusinessModel {
        let docRef = Firestore.firestore().collection("businesses").document(businessID)
        let snapshot = try await docRef.getDocument()

        guard snapshot.exists else {
            throw NSError(domain: "FirestoreService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Business not found"])
        }

        var business = try snapshot.data(as: BusinessModel.self)
        business.id = snapshot.documentID
        return business
    }
    
    func fetchBusinessByMember(_ userID: String) async throws -> BusinessModel {
        let snapshot = try await db.collection("businesses")
            .whereField("memberIDs", arrayContains: userID)
            .limit(to: 1)
            .getDocuments()

        guard let doc = snapshot.documents.first else {
            throw URLError(.badServerResponse)
        }

        return try doc.data(as: BusinessModel.self)
    }
    
    func fetchBusinessManagedBy(_ managerID: String) async throws -> BusinessModel {
        let snapshot = try await db.collection("businesses")
            .whereField("managerID", isEqualTo: managerID)
            .limit(to: 1)
            .getDocuments()

        guard let doc = snapshot.documents.first else {
            throw URLError(.badServerResponse)
        }

        return try doc.data(as: BusinessModel.self)
    }
    
    func getBusinessMembers(businessID: String) async throws -> [UserModel] {
        let snapshot = try await Firestore.firestore().collection("businesses").document(businessID).getDocument()
        let business = try snapshot.data(as: BusinessModel.self)
        let memberIDs = business.memberIDs

        guard !memberIDs.isEmpty else { return [] }

        var members: [UserModel] = []
        let chunks: [[String]] = stride(from: 0, to: memberIDs.count, by: 10).map { Array(memberIDs[$0..<min($0 + 10, memberIDs.count)]) }

        for chunk in chunks {
            let membersSnapshot = try await Firestore.firestore().collection("users")
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()

            let batch = try membersSnapshot.documents.compactMap { try $0.data(as: UserModel.self) }
            members.append(contentsOf: batch)
        }

        return members
    }
    
    func saveResponseTime(forBusinessID businessID: String, responseTime: TimeInterval) async throws {
        let data: [String: Any] = [
            "businessID": businessID,
            "responseTime": responseTime,
            "timestamp": Timestamp(date: Date())
        ]

        let _ = try await Firestore.firestore()
            .collection("responseTimes")
            .addDocument(data: data)
    }
    
    func checkFastResponderBadge(for businessID: String) async throws -> Bool {
        let snapshot = try await Firestore.firestore()
            .collection("responseTimes")
            .whereField("businessID", isEqualTo: businessID)
            .order(by: "timestamp", descending: true)
            .limit(to: 20) // Evaluate last 20 responses

            .getDocuments()

        let responseTimes = snapshot.documents.compactMap {
            $0.data()["responseTime"] as? Double
        }

        guard !responseTimes.isEmpty else { return false }

        let average = responseTimes.reduce(0, +) / Double(responseTimes.count)
        return average <= 7200 // 2 hours
    }
    
    func updateBusinessLateJobDate(businessID: String) async throws {
        try await Firestore.firestore().collection("businesses")
            .document(businessID)
            .updateData(["lastLateJob": Timestamp(date: Date())])
    }
    
    func calculateRepeatClientRate(for businessID: String) async throws -> Double {
        let snapshot = try await Firestore.firestore()
            .collection("bookings")
            .whereField("businessID", isEqualTo: businessID)
            .getDocuments()

        let bookings = snapshot.documents.compactMap {
            try? $0.data(as: BookingModel.self)
        }

        // Count of bookings per homeowner
        let grouped = Dictionary(grouping: bookings, by: { $0.homeownerID })

        let totalClients = grouped.count
        let repeatClients = grouped.filter { $1.count > 1 }.count

        guard totalClients > 0 else { return 0.0 }
        return Double(repeatClients) / Double(totalClients)
    }
    
    func calculateAverageCommunicationRating(for businessID: String) async throws -> Double {
        let snapshot = try await Firestore.firestore()
            .collection("reviews")
            .whereField("businessID", isEqualTo: businessID)
            .getDocuments()

        let reviews = snapshot.documents.compactMap {
            try? $0.data(as: ReviewModel.self)
        }

        let commsRatings = reviews.compactMap { $0.communicationRating }
        guard !commsRatings.isEmpty else { return 0.0 }

        let average = commsRatings.reduce(0.0, { $0 + Double($1) }) / Double(commsRatings.count)
        return average
    }
    
    func calculateBusinessLevel(for businessID: String) async throws -> Int {
        let bookings = try await fetchBookingsForBusiness(businessID: businessID)
        let completed = bookings.filter { $0.status == .completed }
        let avgRating = try await calculateAverageRating(for: businessID)

        switch true {
        case completed.count >= 100 && avgRating >= 4.8:
            return 3
        case completed.count >= 50 && avgRating >= 4.5:
            return 2
        case completed.count >= 10 && avgRating >= 4.2:
            return 1
        default:
            return 0
        }
    }
    
    func calculateBusinessBadges(for businessID: String) async throws -> [String] {
        var badges: [String] = []
        
        // Fetch necessary data
        let bookings = try await fetchBookingsForBusiness(businessID: businessID)
        let completed = bookings.filter { $0.status == .completed }
        let business = try await fetchBusinessByID(businessID)
        
        let calendar = Calendar.current

        // 1. Fast Responder
        if try await checkFastResponderBadge(for: businessID) {
            badges.append("⚡ Fast Responder")
        }

        // 2. Weekend Warrior
        let weekendJobs = bookings.filter {
            let weekday = calendar.component(.weekday, from: $0.date)
            return weekday == 1 || weekday == 7 // Sunday or Saturday
        }
        if weekendJobs.count >= 5 {
            badges.append("⚡ Weekend Warrior")
        }

        // 3. Always On Time
        if completed.count > 0 {
            if let lastLateJob = business.lastLateJob {
                let twoMonthsAgo = Calendar.current.date(byAdding: .month, value: -2, to: Date())!
                if lastLateJob < twoMonthsAgo {
                    badges.append("⚡ Always On Time")
                }
            } else {
                // No late jobs recorded at all and jobs have been completed
                badges.append("⚡ Always On Time")
            }
        }

        // 4. Yardly Pioneer
        let snapshot = try await db.collection("businesses")
            .order(by: "joinDate", descending: false)
            .limit(to: 500)
            .getDocuments()

        let pioneerIDs = snapshot.documents.compactMap { $0.documentID }
        if pioneerIDs.contains(businessID) {
            badges.append("🌟 Yardly Pioneer")
        }

        // 5. Yardly All-Star
        if business.isStaffPicked == true {
            badges.append("🌟 Yardly All-Star")
        }

        // 6. Featured in Yardly Blog
        if business.featuredInBlog == true {
            badges.append("🌟 Featured in Yardly Blog")
        }

        // 7. Customer Favorite
        let repeatRate = try await calculateRepeatClientRate(for: businessID)

        if repeatRate >= 0.4 {
            badges.append("🤝 Customer Favorite")
        }

        // 8. Excellent Communicator
        let avgCommRating = try await calculateAverageCommunicationRating(for: businessID)

        if avgCommRating >= 4.9 {
            badges.append("🤝 Excellent Communicator")
        }

        // 9. Eco Friendly
        if business.ecoFriendly == true {
            badges.append("🎗️ Eco Friendly")
        }

        // 10. Pet Friendly
        if business.petFriendly == true {
            badges.append("🎗️ Pet Friendly")
        }

        // 11. Family Owned
        if business.familyOwned == true {
            badges.append("🎗️ Family Owned")
        }

        // 12. 100 Jobs Club
        if completed.count >= 100 {
            badges.append("🚀 100 Jobs Club")
        }

        // 13. 500 Jobs Club
        if completed.count >= 500 {
            badges.append("🚀 500 Jobs Club")
        }

        return badges
    }
    
    func updateBusinessLevelAndBadges(businessID: String) async {
        do {
            let level = try await calculateBusinessLevel(for: businessID)
            let badges = try await calculateBusinessBadges(for: businessID)

            try await Firestore.firestore().collection("businesses").document(businessID).updateData([
                "level": level,
                "badges": badges
            ])
        } catch {
            print("Failed to update business level and badges: \(error.localizedDescription)")
        }
    }
    
    func getAvailabilityMap(for businessID: String) async throws -> [String: [String]] {
        let doc = try await Firestore.firestore().collection("businesses").document(businessID).getDocument()
        guard let data = doc.data(),
              let slots = data["availability"] as? [[String: Any]] else { return [:] }

        var map: [String: [String]] = [:]
        for slot in slots {
            if let day = slot["day"] as? String,
               let times = slot["timeRanges"] as? [String] {
                map[day] = times
            }
        }
        return map
    }
    
    func getUnavailableSlotsByDate(businessID: String, startDate: Date, days: Int) async throws -> [Date: [String]] {
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .day, value: days, to: startDate) ?? startDate
        let snapshot = try await Firestore.firestore().collection("bookings")
            .whereField("businessID", isEqualTo: businessID)
            .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: startDate))
            .whereField("date", isLessThanOrEqualTo: Timestamp(date: endDate))
            .getDocuments()

        var result: [Date: [String]] = [:]
        for doc in snapshot.documents {
            if let timestamp = doc.data()["date"] as? Timestamp,
               let slot = doc.data()["timeSlot"] as? String {
                let date = calendar.startOfDay(for: timestamp.dateValue())
                result[date, default: []].append(slot)
            }
        }
        return result
    }
    
    func createOrUpdateChatThread(
        threadID: String,
        participants: [String],
        lastMessage: String,
        lastSenderID: String
    ) async throws {
        let db = Firestore.firestore()
        let threadRef = db.collection("chatThreads").document(threadID)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            db.runTransaction({ (transaction, errorPointer) -> Any? in
                do {
                    let snapshot = try transaction.getDocument(threadRef)
                    var unreadCounts = snapshot.data()?["unreadCounts"] as? [String: Int] ?? [:]

                    for participant in participants {
                        if participant == lastSenderID {
                            unreadCounts[participant] = 0
                        } else {
                            unreadCounts[participant] = (unreadCounts[participant] ?? 0) + 1
                        }
                    }

                    transaction.setData([
                        "participants": participants,
                        "lastMessage": lastMessage,
                        "lastMessageTimestamp": FieldValue.serverTimestamp(),
                        "lastSenderID": lastSenderID,
                        "unreadCounts": unreadCounts
                    ], forDocument: threadRef, merge: true)

                    return nil
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }) { (_, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func decrementServiceBookingCount(serviceID: String) async {
        let serviceRef = db.collection("services").document(serviceID)
        do {
            try await serviceRef.updateData([
                "bookingsCount": FieldValue.increment(Int64(-1))
            ])
        } catch {
            print("Failed to decrement bookingsCount: \(error.localizedDescription)")
        }
    }
}
