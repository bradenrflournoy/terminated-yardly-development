// ServiceDetailScreen.swift

import SwiftUI
import FirebaseFirestore
import MapKit
import CoreLocation

struct ServiceDetailScreen: View {
    let service: ServiceModel
    let business: BusinessModel
    
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate = Date()
    @State private var selectedTimeSlot: String? = nil
    @State private var isRecurring = false
    @State private var isSubmitting = false
    @State private var submissionMessage: String? = nil
    @State private var availableDays: Set<String> = []
    @State private var availabilityMap: [String: [String]] = [:]
    @State private var unavailableSlots: Set<String> = []
    @State private var selectedCoordinate: CLLocationCoordinate2D? = nil
    @State private var selectedAddress: String = ""
    @State private var showImageFullScreen = false
    @State private var imageScale: CGFloat = 1.0
    @State private var lastScaleValue: CGFloat = 1.0
    @State private var recurringIntervalWeeks: Int = 1

    private let firestoreService = FirestoreService()
    private let geocoder = CLGeocoder()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                if let imageURL = service.imageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 200)
                            .clipped()
                            .cornerRadius(10)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 200)
                            .overlay(ProgressView())
                            .cornerRadius(10)
                    }
                    .onTapGesture {
                        showImageFullScreen = true
                    }
                }

                Group {
                    Text(service.title)
                        .font(.largeTitle)
                        .bold()

                    NavigationLink(value: business) {  // Navigate to BusinessProfileScreen
                        HStack {
                            Image(systemName: "building.2")
                                .foregroundColor(.accentColor)
                            Text("Offered by \(business.businessName)")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .font(.subheadline)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .padding(.horizontal)

                    Text("\(service.description)")
                        .font(.body)
                        .padding(.top)

                    Text("Price: $\(service.price, specifier: "%.2f")")
                        .font(.title2)
                        .padding(.vertical)

                    DatePicker("Select Date", selection: $selectedDate, in: Date()..., displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .onChange(of: selectedDate) { _ in Task { await fetchUnavailableSlots() } }

                    if isDateAvailable(selectedDate), let times = availableTimeSlots(for: selectedDate) {
                        Text("Available slots: \(times.filter { !unavailableSlots.contains(normalizedSlot($0)) }.joined(separator: ", "))")
                            .font(.footnote)
                            .foregroundColor(.green)
                            .padding(.bottom, 4)
                    } else {
                        Text("No availability on this day.")
                            .font(.footnote)
                            .foregroundColor(.red)
                            .padding(.bottom, 4)
                    }

                    if let times = availableTimeSlots(for: selectedDate), !times.isEmpty {
                        Picker("Time Slot", selection: $selectedTimeSlot) {
                            Text("Select a time slot").tag(Optional<String>(nil))
                            ForEach(times, id: \.self) { slot in
                                Text(unavailableSlots.contains(normalizedSlot(slot)) ? "\(slot) (Unavailable)" : slot)
                                    .foregroundColor(unavailableSlots.contains(normalizedSlot(slot)) ? .gray : .primary)
                                    .tag(Optional(slot))
                                    .disabled(unavailableSlots.contains(normalizedSlot(slot)))
                            }
                        }
                        .pickerStyle(.menu)
                    } else if isDateAvailable(selectedDate) {
                        Text("No time slots available on this day.")
                            .font(.footnote)
                            .foregroundColor(.gray)
                    }

                    Toggle("Recurring Service", isOn: $isRecurring)
                        .padding(.top)
                    
                    if isRecurring {
                        Picker("Repeat Every", selection: $recurringIntervalWeeks) {
                            ForEach(1..<13) { weeks in
                                Text("\(weeks) week\(weeks > 1 ? "s" : "")").tag(weeks)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(.bottom)
                    }
                }

                Group {
                    TappableMapView(coordinate: $selectedCoordinate) { newCoordinate in
                        reverseGeocodeSelectedLocation(from: newCoordinate)
                    }
                    .frame(height: 200)

                    if !selectedAddress.isEmpty {
                        Text("Location: \(selectedAddress)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }

                    if let message = submissionMessage {
                        Text(message)
                            .foregroundColor(message == "Booking confirmed!" ? .green : .red)
                            .padding(.top)
                    }

                    Button(action: bookService) {
                        if isSubmitting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Book Now")
                                .bold()
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(Color("BGColor"))
                    .cornerRadius(10)
                    .padding(.top)
                    .disabled(!isDateAvailable(selectedDate) || selectedTimeSlot == nil || unavailableSlots.contains(normalizedSlot(selectedTimeSlot ?? "")))
                }
            }
            .padding()
        }
        .navigationTitle("Service Details")
        .onAppear {
            Task {
                await loadAvailability()
                await fetchUnavailableSlots()
            }
        }
        .fullScreenCover(isPresented: $showImageFullScreen) {
            ZStack(alignment: .topTrailing) {
                Color.black.ignoresSafeArea()

                if let imageURL = service.imageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(imageScale)
                            .gesture(MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScaleValue
                                    lastScaleValue = value
                                    imageScale *= delta
                                }
                                .onEnded { _ in
                                    lastScaleValue = 1.0
                                }
                            )
                            .ignoresSafeArea()
                    } placeholder: {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.black)
                    }
                }

                Button(action: {
                    showImageFullScreen = false
                    imageScale = 1.0
                    lastScaleValue = 1.0
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .resizable()
                        .frame(width: 32, height: 32)
                        .foregroundColor(.white)
                        .padding()
                }
            }
        }
        .applyAppBackground()
    }

    private func reverseGeocodeSelectedLocation(from coordinate: CLLocationCoordinate2D) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let placemark = placemarks?.first {
                selectedAddress = [placemark.name, placemark.locality, placemark.administrativeArea].compactMap { $0 }.joined(separator: ", ")
            }
        }
    }

    private func loadAvailability() async {
        do {
            let doc = try await Firestore.firestore().collection("businesses").document(service.businessID).getDocument()
            if let data = doc.data(),
               let slots = data["availability"] as? [[String: Any]] {
                var daySet = Set<String>()
                var dayMap: [String: [String]] = [:]
                for slot in slots {
                    if let day = slot["day"] as? String {
                        daySet.insert(day)
                        let times = slot["timeRanges"] as? [String] ?? []
                        dayMap[day] = times
                    }
                }
                availableDays = daySet
                availabilityMap = dayMap
            }
        } catch {
            print("Error loading availability: \(error.localizedDescription)")
        }
    }

    private func fetchUnavailableSlots() async {
        unavailableSlots = []
        var calendar = Calendar.current
        if let tz = TimeZone(identifier: business.timeZone) {
            calendar.timeZone = tz
        }
        let startOfDay = calendar.startOfDay(for: selectedDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? selectedDate

        let snapshot = try? await Firestore.firestore().collection("bookings")
            .whereField("businessID", isEqualTo: service.businessID)
            .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .whereField("date", isLessThan: Timestamp(date: endOfDay))
            .getDocuments()

        if let documents = snapshot?.documents {
            for doc in documents {
                if let slot = doc.data()["timeSlot"] as? String {
                    unavailableSlots.insert(normalizedSlot(slot))
                }
            }
        }
    }

    private func isDateAvailable(_ date: Date) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.timeZone = TimeZone(identifier: business.timeZone)
        let weekday = formatter.string(from: date)
        return availableDays.contains(weekday)
    }

    private func availableTimeSlots(for date: Date) -> [String]? {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.timeZone = TimeZone(identifier: business.timeZone)
        let weekday = formatter.string(from: date)
        return availabilityMap[weekday]
    }

    private func bookService() {
        guard let userID = authVM.currentUser?.id else { return }
        isSubmitting = true

        Task {
            do {
                // Fetch business to get timezone and supervision info first
                let businessDoc = try await Firestore.firestore()
                    .collection("businesses")
                    .document(service.businessID)
                    .getDocument()
                let biz = try businessDoc.data(as: BusinessModel.self)
                let tz = biz.timeZone

                let slotTaken = try await checkDuplicateTimeSlot(
                    userID: userID,
                    businessID: service.businessID,
                    date: selectedDate,
                    timeSlot: selectedTimeSlot,
                    timeZoneIdentifier: tz
                )
                let userConflict = try await checkUserOverlap(
                    userID: userID,
                    date: selectedDate,
                    timeSlot: selectedTimeSlot,
                    timeZoneIdentifier: tz
                )

                if slotTaken {
                    submissionMessage = "This time slot is already booked."
                } else if userConflict {
                    submissionMessage = "You already have another job at this time."
                } else {
                    let isSupervised = biz.supervisorID != nil

                    let booking = BookingModel(
                        id: nil,
                        homeownerID: userID,
                        businessID: service.businessID,
                        service: service,
                        date: selectedDate,
                        timeSlot: selectedTimeSlot,
                        isRecurring: isRecurring,
                        recurringIntervalWeeks: isRecurring ? recurringIntervalWeeks : nil,
                        status: isSupervised ? .pendingApproval : .scheduled,
                        requiresApproval: isSupervised,
                        isApproved: !isSupervised,
                        timeZone: tz,
                        latitude: selectedCoordinate?.latitude,
                        longitude: selectedCoordinate?.longitude,
                        locationDescription: selectedAddress
                    )

                    try await firestoreService.bookService(booking)
                    submissionMessage = "Booking confirmed!"
                }
            } catch {
                submissionMessage = "Failed to book service. Please try again."
            }

            isSubmitting = false
        }
    }

    private func checkDuplicateTimeSlot(userID: String, businessID: String, date: Date, timeSlot: String?, timeZoneIdentifier: String) async throws -> Bool {
        guard let timeSlot = timeSlot else { return true }

        var calendar = Calendar.current
        if let tz = TimeZone(identifier: timeZoneIdentifier) {
            calendar.timeZone = tz
        }
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date

        let snapshot = try await Firestore.firestore().collection("bookings")
            .whereField("businessID", isEqualTo: businessID)
            .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .whereField("date", isLessThan: Timestamp(date: endOfDay))
            .whereField("timeSlot", isEqualTo: timeSlot)
            .getDocuments()

        return !snapshot.documents.isEmpty
    }

    private func checkUserOverlap(userID: String, date: Date, timeSlot: String?, timeZoneIdentifier: String) async throws -> Bool {
        guard let timeSlot = timeSlot else { return false }

        var calendar = Calendar.current
        if let tz = TimeZone(identifier: timeZoneIdentifier) {
            calendar.timeZone = tz
        }
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date

        let snapshot = try await Firestore.firestore().collection("bookings")
            .whereField("homeownerID", isEqualTo: userID)
            .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .whereField("date", isLessThan: Timestamp(date: endOfDay))
            .whereField("timeSlot", isEqualTo: timeSlot)
            .getDocuments()

        return !snapshot.documents.isEmpty
    }

    private func normalizedSlot(_ s: String) -> String {
        s.lowercased().replacingOccurrences(of: " ", with: "")
    }
}

struct LocationAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

