// NotificationsScreen.swift

import SwiftUI

struct NotificationsScreen: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var notifications: [NotificationModel] = []
    @State private var isLoading = true

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading...")
                    .padding()
            } else if notifications.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "bell.slash.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                        .padding(.bottom, 10)

                    Text("No notifications yet")
                        .font(.title3)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(notifications) { notification in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(notification.title)
                                .font(.headline)
                                .foregroundColor(notification.read ? .secondary : .primary)

                            Text(notification.message)
                                .font(.subheadline)
                                .foregroundColor(notification.read ? .secondary : .primary)

                            Text(notification.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                        .opacity(notification.read ? 0.6 : 1.0)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if !notification.read {
                                Button("Read") {
                                    if let id = notification.id {
                                        markAsRead(notificationID: id)
                                    }
                                }
                                .tint(.blue)
                            }

                            Button("Delete", role: .destructive) {
                                if let id = notification.id {
                                    deleteNotification(notificationID: id)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .task {
            await loadNotifications()
        }
        .applyAppBackground()
    }

    private func loadNotifications() async {
        guard let uid = authVM.currentUser?.id else { return }
        do {
            notifications = try await FirestoreService().fetchNotifications(for: uid)
        } catch {
            print("Error fetching notifications: \(error.localizedDescription)")
        }
        isLoading = false
    }

    private func markAsRead(notificationID: String) {
        NotificationManager.shared.markAsRead(notificationID: notificationID)
        if let index = notifications.firstIndex(where: { $0.id == notificationID }) {
            notifications[index].read = true
        }
    }

    private func deleteNotification(notificationID: String) {
        NotificationManager.shared.deleteNotification(notificationID: notificationID)
        notifications.removeAll { $0.id == notificationID }
    }
}
