// JobHistoryScreen.swift

import SwiftUI
import FirebaseFirestore

struct BusinessIDWrapper: Identifiable {
    var id: String { value }
    let value: String
}

struct JobHistoryScreen: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var bookings: [BookingModel] = []
    @State private var isLoading = true
    @State private var selectedBusinessID: BusinessIDWrapper? = nil
    @State private var reviewedBusinessIDs: Set<String> = []

    private let db = Firestore.firestore()

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                if isLoading {
                    ProgressView("Loading job history...")
                        .padding()
                } else if bookings.isEmpty {
                    VStack {
                        Spacer()
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                            .padding(.bottom, 10)

                        Text("No job history yet.")
                            .font(.title3)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(bookings) { booking in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(booking.service.title)
                                .font(.headline)
                            Text("Status: \(booking.status.rawValue.capitalized)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Scheduled for: \(booking.date.formatted(date: .abbreviated, time: .shortened))" + (booking.timeSlot != nil ? " at \(booking.timeSlot!)" : ""))
                                .font(.footnote)
                                .foregroundColor(.gray)

                            if let location = booking.locationDescription, !location.isEmpty {
                                Text("Location: \(location)")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }

                            if authVM.currentUser?.role == .homeowner && booking.status == .completed && !reviewedBusinessIDs.contains(booking.businessID) {
                                Button("Leave a Review") {
                                    selectedBusinessID = BusinessIDWrapper(value: booking.businessID)
                                }
                                .font(.caption)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .task {
                await loadHistory()
                await loadReviewedBusinessIDs()
            }
            .sheet(item: $selectedBusinessID) { wrapper in
                LeaveReviewWindow(businessID: wrapper.value)
                    .environmentObject(authVM)
            }
            .applyAppBackground()
        }
        .navigationTitle("Job History")
    }

    private func loadHistory() async {
        guard let user = authVM.currentUser else { return }

        var queries: [Query] = []

        if let userID = user.id {
            let bookedQuery = db.collection("bookings")
                .whereField("homeownerID", isEqualTo: userID)
                .whereField("status", in: ["completed", "cancelled"])
            queries.append(bookedQuery)
        }

        if let businessID = user.businessID, user.role == .teen || user.role == .supervisor {
            let businessQuery = db.collection("bookings")
                .whereField("businessID", isEqualTo: businessID)
                .whereField("status", in: ["completed", "cancelled"])
            queries.append(businessQuery)
        }

        do {
            var allBookings: [BookingModel] = []

            for query in queries {
                let snapshot = try await query.getDocuments()
                let results = snapshot.documents.compactMap { try? $0.data(as: BookingModel.self) }
                allBookings.append(contentsOf: results)
            }

            bookings = allBookings
                .sorted(by: { $0.date > $1.date })

        } catch {
            print("Error fetching job history: \(error.localizedDescription)")
            bookings = []
        }

        isLoading = false
    }

    private func loadReviewedBusinessIDs() async {
        guard let userID = authVM.currentUser?.id else { return }
        do {
            let snapshot = try await db.collection("reviews")
                .whereField("reviewerID", isEqualTo: userID)
                .getDocuments()
            reviewedBusinessIDs = Set(snapshot.documents.compactMap { doc in
                try? doc.data(as: ReviewModel.self).businessID
            })
        } catch {
            print("Error loading reviewed businesses: \(error.localizedDescription)")
        }
    }
}
