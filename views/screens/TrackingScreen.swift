// TrackingScreen.swift

import SwiftUI
import MapKit
import FirebaseFirestore
#if canImport(FirebaseFirestoreSwift)
import FirebaseFirestoreSwift   // works on your friend’s older toolchain
#endif

struct TeenLocation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

struct TrackingScreen: View {
    var booking: BookingModel
    var teen: UserModel

    @State private var teenLocation: TeenLocation?
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var listener: ListenerRegistration?
    @State private var teenName: String = ""
    @State private var homeownerName: String = ""
    @State private var teenPhoneNumber: String = ""

    @State private var followTeen: Bool = true
    @State private var lastUpdatedAt: Date? = nil

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                if let teenLocation = teenLocation {
                    Map(coordinateRegion: $region, annotationItems: [teenLocation]) { location in
                        MapMarker(coordinate: location.coordinate, tint: .blue)
                    }
                    .frame(height: 300)
                    .cornerRadius(10)
                } else {
                    ProgressView("Waiting for location update...")
                }

                HStack {
                    Toggle("Follow", isOn: $followTeen)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let last = lastUpdatedAt {
                        Text("Last updated: \(last.formatted(date: .omitted, time: .standard))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Service: \(booking.service.title)")
                        .font(.headline)
                    Text("Teen: \(teenName)")
                    Text("Homeowner: \(homeownerName)")
                    if let location = booking.locationDescription {
                        Text("Location: \(location)")
                    }
                    Text("Scheduled: \(booking.date.formatted(date: .abbreviated, time: .shortened))")

                    if !teenPhoneNumber.isEmpty {
                        Button(action: {
                            let digits = teenPhoneNumber.filter { $0.isNumber }
                            if let url = URL(string: "tel://\(digits)"), !digits.isEmpty {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Label("Call Teen", systemImage: "phone.fill")
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                }
                .padding()

                Spacer()
            }
            .padding(.vertical)
            .navigationTitle("Tracking")
            .applyAppBackground()
        }
        .onAppear(perform: startListening)
        .onDisappear {
            listener?.remove()
        }
    }

    private func startListening() {
        let db = Firestore.firestore()

        Task {
            guard let trackingUserID = teen.id else { return }
            let teenDoc = try await db.collection("users").document(trackingUserID).getDocument()
            if let data = teenDoc.data(),
               let teenUser = try? teenDoc.data(as: UserModel.self),
               let geoPoint = data["location"] as? GeoPoint {

                teenName = teenUser.name
                teenPhoneNumber = data["phoneNumber"] as? String ?? ""

                let coord = CLLocationCoordinate2D(latitude: geoPoint.latitude, longitude: geoPoint.longitude)
                self.teenLocation = TeenLocation(coordinate: coord)
                if let ts = data["locationUpdatedAt"] as? Timestamp { self.lastUpdatedAt = ts.dateValue() } else { self.lastUpdatedAt = Date() }
                if followTeen { self.region.center = coord }

                self.listener = db.collection("users").document(trackingUserID)
                    .addSnapshotListener { snapshot, _ in
                        if let updatedData = snapshot?.data(),
                           let updatedLocation = updatedData["location"] as? GeoPoint {
                            let updatedCoord = CLLocationCoordinate2D(
                                latitude: updatedLocation.latitude,
                                longitude: updatedLocation.longitude
                            )
                            self.teenLocation = TeenLocation(coordinate: updatedCoord)
                            if let ts = updatedData["locationUpdatedAt"] as? Timestamp { self.lastUpdatedAt = ts.dateValue() } else { self.lastUpdatedAt = Date() }
                            if followTeen { self.region.center = updatedCoord }
                        }
                    }
            }

            let homeownerDoc = try await db.collection("users").document(booking.homeownerID).getDocument()
            if let homeownerUser = try? homeownerDoc.data(as: UserModel.self) {
                homeownerName = homeownerUser.name
            }
        }
    }
}

