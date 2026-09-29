// NotificationManager.swift

import Foundation
import FirebaseFirestore

class NotificationManager {
    static let shared = NotificationManager()
    private let db = Firestore.firestore()

    private init() {}

    func sendNotification(to userID: String, title: String, message: String) {
        let notification = [
            "userID": userID,
            "title": title,
            "message": message,
            "timestamp": Timestamp(date: Date()),
            "read": false
        ] as [String : Any]

        db.collection("notifications").addDocument(data: notification) { error in
            if let error = error {
                print("Failed to send notification: \(error.localizedDescription)")
            }
        }
    }
    
    func markAsRead(notificationID: String) {
        db.collection("notifications").document(notificationID).updateData(["read": true]) { error in
            if let error = error {
                print("Failed to mark notification as read: \(error.localizedDescription)")
            }
        }
    }

    func deleteNotification(notificationID: String) {
        db.collection("notifications").document(notificationID).delete { error in
            if let error = error {
                print("Failed to delete notification: \(error.localizedDescription)")
            }
        }
    }

    // Booking confirmed (to business member)
    func notifyBookingConfirmed(businessMemberID: String, serviceTitle: String) {
        sendNotification(to: businessMemberID, title: "New Booking", message: "You have a new booking for \(serviceTitle).")
    }

    // Booking completed (to homeowner)
    func notifyBookingCompleted(homeownerID: String, serviceTitle: String) {
        sendNotification(to: homeownerID, title: "Job Completed", message: "Your booking for \(serviceTitle) has been marked as completed.")
    }

    // Booking cancelled (to other party)
    func notifyBookingCancelled(to userID: String, serviceTitle: String) {
        sendNotification(to: userID, title: "Booking Cancelled", message: "Your booking for \(serviceTitle) was cancelled.")
    }

    // New message
    func notifyNewMessage(to userID: String, senderName: String) {
        sendNotification(to: userID, title: "New Message", message: "You received a message from \(senderName).")
    }
    
    // New image
    func notifyNewImage(to userID: String, senderName: String) {
        sendNotification(to: userID, title: "New Image", message: "You received an image from \(senderName).")
    }
    
    func notifyRecurringFailed(homeownerID: String, serviceTitle: String) {
        sendNotification(
            to: homeownerID,
            title: "Recurring Booking Not Scheduled",
            message: "We couldn't schedule your next recurring service for \(serviceTitle) due to limited availability. You may want to reschedule manually."
        )
    }
}
