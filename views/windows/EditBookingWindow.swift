// EditBookingWindow.swift

import SwiftUI
import FirebaseFirestore

struct EditBookingWindow: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authVM: AuthViewModel

    let booking: BookingModel
    let onUpdate: () -> Void

    @State private var newDate: Date
    @State private var newTimeSlot: String?
    @State private var availabilityMap: [String: [String]] = [:]
    @State private var unavailableSlots: Set<String> = []
    @State private var message: String? = nil
    @State private var isSaving = false
    @State private var showSuccess = false

    private let firestore = Firestore.firestore()
    private let firestoreService = FirestoreService()

    init(booking: BookingModel, onUpdate: @escaping () -> Void) {
        self.booking = booking
        self.onUpdate = onUpdate
        _newDate = State(initialValue: booking.date)
        _newTimeSlot = State(initialValue: booking.timeSlot)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Booking")
                .font(.title2)
                .bold()

            DatePicker("New Date", selection: $newDate, in: Date()..., displayedComponents: .date)
                .datePickerStyle(.graphical)
                .onChange(of: newDate) { _ in Task { await fetchUnavailableSlots() } }

            if let slots = availabilityMap[weekday(for: newDate)], !slots.isEmpty {
                Picker("Time Slot", selection: $newTimeSlot) {
                    Text("Select a time slot").tag(Optional<String>(nil))
                    ForEach(slots, id: \.self) { slot in
                        if unavailableSlots.contains(slot) && slot != booking.timeSlot {
                            Text("\(slot) (Unavailable)").foregroundColor(.gray)
                        } else {
                            Text(slot).tag(Optional(slot))
                        }
                    }
                }
                .pickerStyle(.menu)
            } else {
                Text("No available time slots for this day.")
                    .font(.footnote)
                    .foregroundColor(.red)
            }

            if let message = message {
                Text(message)
                    .foregroundColor(.red)
            }

            Button("Save Changes") {
                Task { await saveChanges() }
            }
            .disabled(isSaving || newTimeSlot == nil || isWithin24Hours(date: newDate))
            .buttonStyle(.borderedProminent)
            .padding(.top)

            if isWithin24Hours(date: newDate) {
                Text("Edits must be made more than 24 hours in advance.")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            Spacer()
        }
        .padding()
        .onAppear {
            Task {
                await loadAvailability()
                await fetchUnavailableSlots()
            }
        }
        .alert("Booking Updated", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("Your changes have been saved.")
        }
    }

    private func weekday(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    private func loadAvailability() async {
        do {
            let doc = try await firestore.collection("businesses").document(booking.businessID).getDocument()
            if let data = doc.data(),
               let slots = data["availability"] as? [[String: Any]] {
                for slot in slots {
                    if let day = slot["day"] as? String,
                       let times = slot["timeRanges"] as? [String] {
                        availabilityMap[day] = times
                    }
                }
            }
        } catch {
            print("Error loading availability: \(error.localizedDescription)")
        }
    }

    private func fetchUnavailableSlots() async {
        unavailableSlots = []
        let snapshot = try? await firestore.collection("bookings")
            .whereField("businessID", isEqualTo: booking.businessID)
            .whereField("date", isEqualTo: Timestamp(date: newDate))
            .getDocuments()

        if let documents = snapshot?.documents {
            for doc in documents {
                if let slot = doc.data()["timeSlot"] as? String,
                   doc.documentID != booking.id {
                    unavailableSlots.insert(slot)
                }
            }
        }
    }

    private func isWithin24Hours(date: Date) -> Bool {
        return date.timeIntervalSinceNow < 86400 // 24 hours in seconds
    }

    private func saveChanges() async {
        guard let id = booking.id, let slot = newTimeSlot else { return }
        isSaving = true
        message = nil

        do {
            try await firestore.collection("bookings").document(id).updateData([
                "date": Timestamp(date: newDate),
                "timeSlot": slot
            ])
            showSuccess = true
            onUpdate()
        } catch {
            message = "Failed to update booking."
        }

        isSaving = false
    }
}
