// ActiveJobsScreen.swift

import SwiftUI
import FirebaseFirestore
import CoreLocation

struct ActiveJobsScreen: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var bookings: [BookingModel] = []
    @State private var isLoading = true
    @State private var selectedBooking: BookingModel? = nil

    private let firestore = Firestore.firestore()
    private let firestoreService = FirestoreService()

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    VStack {
                        ProgressView("Loading jobs...")
                            .padding()
                    }
                } else if bookings.isEmpty {
                    VStack {
                        Spacer()
                        Image(systemName: "briefcase.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                            .padding(.bottom, 10)

                        Text("No active jobs at the moment.")
                            .font(.title3)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(bookings) { booking in
                            ActiveJobCardView(
                                booking: booking,
                                isTeen: authVM.currentUser?.role == .teen && authVM.currentUser?.businessID == booking.businessID,
                                isHomeowner: authVM.currentUser?.role == .homeowner,
                                onEditTapped: {
                                    selectedBooking = booking
                                },
                                onStatusChanged: {
                                    await loadBookings()
                                },
                                businessID: booking.businessID
                            )
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .applyAppBackground()
        }
        .navigationTitle("Active Jobs")
        .sheet(item: $selectedBooking) { booking in
            EditBookingWindow(booking: booking) {
                Task { await loadBookings() }
            }
        }
        .task {
            await loadBookings()
        }
    }

    private func loadBookings() async {
        guard let user = authVM.currentUser else { return }

        let firestore = Firestore.firestore()

        var queries: [Query] = []

        if let userID = user.id {
            let requestedJobsQuery = firestore.collection("bookings")
                .whereField("homeownerID", isEqualTo: userID)
                .whereField("status", in: ["scheduled", "inProgress"])
            queries.append(requestedJobsQuery)
        }

        if let businessID = user.businessID {
            let assignedJobsQuery = firestore.collection("bookings")
                .whereField("businessID", isEqualTo: businessID)
                .whereField("status", in: ["scheduled", "inProgress"])
            queries.append(assignedJobsQuery)
        }

        do {
            var allBookings: [BookingModel] = []

            for query in queries {
                let snapshot = try await query.getDocuments()
                let results = snapshot.documents.compactMap { try? $0.data(as: BookingModel.self) }
                allBookings.append(contentsOf: results)
            }

            bookings = allBookings
                .sorted { $0.date < $1.date }

        } catch {
            print("Error fetching bookings: \(error.localizedDescription)")
            bookings = []
        }

        isLoading = false
    }
}

func isJobStartedLate(booking: BookingModel) -> Bool {
    let timeSlot = booking.timeSlot
    let timeZoneIdentifier = booking.timeZone

    guard let timeSlot = timeSlot,
          let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
        return false
    }

    var calendar = Calendar.current
    calendar.timeZone = timeZone

    // Parse start of time range, e.g., "9am-12pm"
    let normalized = timeSlot.replacingOccurrences(of: " ", with: "").lowercased()
    guard let startComponent = normalized.split(separator: "-").first else { return false }

    // Normalize to "h a" format, e.g., "9am" -> "9 AM"
    let cleaned = startComponent
        .replacingOccurrences(of: "am", with: " AM")
        .replacingOccurrences(of: "pm", with: " PM")
        .trimmingCharacters(in: .whitespaces)

    let formatter = DateFormatter()
    formatter.timeZone = timeZone
    formatter.dateFormat = "h a"

    guard let startTimeOnly = formatter.date(from: cleaned) else { return false }

    // Merge booking date with parsed start time
    let day = calendar.dateComponents([.year, .month, .day], from: booking.date)
    let time = calendar.dateComponents([.hour, .minute], from: startTimeOnly)

    let scheduledStart = calendar.date(from: DateComponents(
        timeZone: timeZone,
        year: day.year,
        month: day.month,
        day: day.day,
        hour: time.hour,
        minute: time.minute
    )) ?? booking.date

    let allowedStartDeadline = scheduledStart.addingTimeInterval(AppConfig.latenessGraceSeconds) // replaced with AppConfig constant

    return Date() > allowedStartDeadline
}

func isBookingLocked(_ bookingDate: Date) -> Bool {
    let now = Date()
    let timeRemaining = Calendar.current.dateComponents([.hour], from: now, to: bookingDate).hour ?? 0
    return timeRemaining < AppConfig.cancellationLockHours
}

struct ActiveJobCardView: View {
    var booking: BookingModel
    var isTeen: Bool
    var isHomeowner: Bool
    var onEditTapped: () -> Void
    var onStatusChanged: () async -> Void
    var businessID: String

    @State private var showCancelConfirm = false
    @State private var cancelRole: UserRole? = nil
    @State private var showTooFarAlert = false

    private let firestore = Firestore.firestore()
    private let firestoreService = FirestoreService()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(booking.service.title)
                .font(.headline)

            Text("Scheduled for: \(booking.date.formatted(date: .abbreviated, time: .shortened))" + (booking.timeSlot != nil ? " at \(booking.timeSlot!)" : ""))
                .font(.subheadline)
                .foregroundColor(.secondary)

            if let location = booking.locationDescription, !location.isEmpty {
                Text("Location: \(location)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text("Status: \(booking.status.rawValue.capitalized)")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
        .confirmationDialog("Are you sure you want to cancel this booking?", isPresented: $showCancelConfirm, titleVisibility: .visible) {
            Button("Yes, Cancel", role: .destructive) {
                Task {
                    if let id = booking.id {
                        try? await firestoreService.updateBookingStatus(id: id, to: .cancelled)

                        let members = try? await firestoreService.getBusinessMembers(businessID: booking.businessID)
                        members?.forEach { member in
                            NotificationManager.shared.notifyBookingCancelled(
                                to: member.id ?? "",
                                serviceTitle: booking.service.title
                            )
                        }

                        NotificationManager.shared.notifyBookingCancelled(
                            to: booking.homeownerID,
                            serviceTitle: booking.service.title
                        )

                        await onStatusChanged()
                    }
                }
            }
            Button("No", role: .cancel) { }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if isTeen {
                if !isBookingLocked(booking.date) {
                    Button(role: .destructive) {
                        cancelRole = .teen
                        showCancelConfirm = true
                    } label: {
                        Label("Cancel", systemImage: "xmark")
                    }
                }

                if booking.status == .scheduled {
                    Button {
                        Task {
                            guard let jobLat = booking.latitude,
                                  let jobLong = booking.longitude else {
                                print("No job location available.")
                                return
                            }

                            let jobLocation = CLLocation(latitude: jobLat, longitude: jobLong)
                            let service = OneShotLocationManager()
                            let currentLocation = await service.currentLocation(timeout: 8.0)

                            guard let currentLocation else {
                                print("No current location available.")
                                return
                            }

                            let distance = currentLocation.distance(from: jobLocation)

                            if distance > 100 {
                                showTooFarAlert = true
                                return
                            }

                            if let id = booking.id {
                                if isJobStartedLate(booking: booking) {
                                    try? await firestoreService.updateBusinessLateJobDate(businessID: booking.businessID)
                                }

                                try? await firestoreService.updateBookingStatus(id: id, to: .inProgress)

                                let members = try? await firestoreService.getBusinessMembers(businessID: booking.businessID)
                                members?.forEach { member in
                                    NotificationManager.shared.notifyBookingConfirmed(
                                        businessMemberID: member.id ?? "",
                                        serviceTitle: booking.service.title
                                    )
                                }

                                await onStatusChanged()
                            }
                        }
                    } label: {
                        Label("Start", systemImage: "play.fill")
                    }
                    .tint(.orange)
                    .alert("Too Far", isPresented: $showTooFarAlert) {
                        Button("OK", role: .cancel) { }
                    } message: {
                        Text("You must be near the job location to start this task.")
                    }
                }

                if booking.status == .inProgress {
                    Button {
                        Task {
                            if let id = booking.id {
                                try? await firestoreService.updateBookingStatus(id: id, to: .completed)

                                await firestoreService.updateBusinessLevelAndBadges(businessID: booking.businessID)

                                NotificationManager.shared.notifyBookingCompleted(
                                    homeownerID: booking.homeownerID,
                                    serviceTitle: booking.service.title
                                )

                                await onStatusChanged()

                                if booking.isRecurring, let interval = booking.recurringIntervalWeeks {
                                    let calendar = Calendar.current
                                    guard let initialDate = calendar.date(byAdding: .weekOfYear, value: interval, to: booking.date) else { return }

                                    let availability = try await firestoreService.getAvailabilityMap(for: booking.businessID)
                                    let unavailableMap = try await firestoreService.getUnavailableSlotsByDate(
                                        businessID: booking.businessID,
                                        startDate: initialDate,
                                        days: 3
                                    )

                                    var scheduled = false

                                    for offset in 0...2 {
                                        guard let dateToCheck = calendar.date(byAdding: .day, value: offset, to: initialDate) else { continue }
                                        let formatter = DateFormatter()
                                        formatter.dateFormat = "EEEE"
                                        let weekday = formatter.string(from: dateToCheck)

                                        if let availableSlots = availability[weekday] {
                                            let takenSlots = unavailableMap[dateToCheck] ?? []
                                            let openSlots = availableSlots.filter { !takenSlots.contains($0) }

                                            if let nextSlot = openSlots.first {
                                                let nextBooking = BookingModel(
                                                    id: nil,
                                                    homeownerID: booking.homeownerID,
                                                    businessID: booking.businessID,
                                                    service: booking.service,
                                                    date: dateToCheck,
                                                    timeSlot: nextSlot,
                                                    isRecurring: true,
                                                    recurringIntervalWeeks: interval,
                                                    status: booking.requiresApproval ? .pendingApproval : .scheduled,
                                                    requiresApproval: booking.requiresApproval,
                                                    isApproved: !booking.requiresApproval,
                                                    timeZone: booking.timeZone,
                                                    latitude: booking.latitude,
                                                    longitude: booking.longitude,
                                                    locationDescription: booking.locationDescription
                                                )
                                                try await firestoreService.bookService(nextBooking)
                                                scheduled = true
                                                break
                                            }
                                        }
                                    }

                                    if !scheduled {
                                        NotificationManager.shared.notifyRecurringFailed(
                                            homeownerID: booking.homeownerID,
                                            serviceTitle: booking.service.title
                                        )
                                    }
                                }
                            }
                        }
                    } label: {
                        Label("Complete", systemImage: "checkmark")
                    }
                    .tint(.green)
                }
            }

            if isHomeowner {
                if !isBookingLocked(booking.date) {
                    Button(role: .destructive) {
                        cancelRole = .homeowner
                        showCancelConfirm = true
                    } label: {
                        Label("Cancel", systemImage: "trash")
                    }

                    Button {
                        onEditTapped()
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }
        }
    }
}

