// HomeScreen.swift

import SwiftUI
import CoreLocation
import FirebaseFirestore

class HomeLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var userLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = locations.first
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            userLocation = nil
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
}

struct HomeScreen: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var services: [ServiceModel] = []
    @State private var businesses: [BusinessModel] = []
    @State private var userBookings: [BookingModel] = []
    @State private var searchQuery: String = ""
    @State private var isLoading = true
    @State private var selectedCategory: String = "All"
    @State private var distanceFilterKm: Double = 5.0
    @StateObject private var locationManager = HomeLocationManager()

    private let firestoreService = FirestoreService()
    private let categories = ["All", "Lawncare", "Snow", "Cleanup"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                        TextField("Search services, businesses...", text: $searchQuery)
                            .textInputAutocapitalization(.none)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)

                    // Scrollable Category Picker
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(categories, id: \.self) { category in
                                Button(action: { selectedCategory = category }) {
                                    Text(category)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(selectedCategory == category ? Color.accentColor : Color(.systemGray5))
                                        .foregroundColor(selectedCategory == category ? Color("BGColor") : .primary)
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Distance slider
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Filter by distance: \(Int(distanceFilterKm)) km")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        Slider(value: $distanceFilterKm, in: 1...50, step: 1)
                            .padding(.horizontal)
                    }
                    
                    Divider()

                    // Popular Services
                    NavigationLink(
                        destination: PopularServicesScreen(
                            services: services,
                            businesses: businesses,
                            userLocation: locationManager.userLocation,
                            maxDistanceKm: distanceFilterKm,
                            currentUserID: authVM.currentUser?.id
                        )
                    ) {
                        HStack {
                            Image(systemName: "star")
                                .foregroundColor(.accentColor)
                            Text("See Popular Services")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .padding(.horizontal)
                    
                    // Featured or Search Results
                    Group {
                        if isLoading {
                            ProgressView()
                                .padding()
                        } else if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedCategory == "All" {
                            Text("Featured Services")
                                .font(.headline)
                                .padding(.horizontal)
                            serviceList(filteredServices())
                        } else {
                            Text("Search Results")
                                .font(.headline)
                                .padding(.horizontal)
                            serviceList(filteredServices())
                        }
                    }

                    // My Jobs
                    Text("My Jobs")
                        .font(.headline)
                        .padding(.horizontal)
                    if isLoading {
                        ProgressView()
                            .padding()
                    } else if userBookings.isEmpty {
                        Text("No bookings yet.")
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                    } else {
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(userBookings) { booking in
                                    BookingCardView(booking: booking)
                                        .padding(.horizontal)
                                }
                            }
                        }
                        .frame(height: 300)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: NotificationsScreen()) {
                        Image(systemName: "bell")
                            .imageScale(.large)
                    }
                }
            }
            .applyAppBackground()
            // Declare all navigation destinations here
            .navigationDestination(for: ServiceModel.self) { service in
                if let business = businesses.first(where: { $0.id == service.businessID }) {
                    ServiceDetailScreen(service: service, business: business)
                }
            }
            .navigationDestination(for: BusinessModel.self) { business in
                BusinessProfileScreen(business: business)
            }
            .navigationDestination(for: UserModel.self) { partner in
                ChatScreen(partner: partner)
            }
        }
        .task {
            async let allServices = firestoreService.fetchServices()
            async let allBusinesses = firestoreService.fetchBusinesses()

            do {
                services = try await allServices
                businesses = try await allBusinesses
                userBookings = try await loadUserBookings()
            } catch {
                print("Error loading home data: \(error.localizedDescription)")
            }
            isLoading = false
        }
    }

    // Services listing helper
    private func serviceList(_ items: [ServiceModel]) -> some View {
        Group {
            if items.isEmpty {
                Text("No services available.")
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            } else {
                VStack(spacing: 12) {
                    ForEach(items) { service in
                        ServiceCardView(service: service, business: businesses.first(where: { $0.id == service.businessID }))
                            .padding(.horizontal)
                    }
                }
            }
        }
    }

    private func filteredServices() -> [ServiceModel] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentUserID = authVM.currentUser?.id
        let userLoc = locationManager.userLocation

        return services.filter { service in
            guard let business = businesses.first(where: { $0.id == service.businessID }) else { return false }

            // Exclude services from user's own business (supervisor or member)
            let isSupervisor = business.supervisorID == currentUserID
            let isMember = business.memberIDs.contains(currentUserID ?? "")
            if isSupervisor || isMember { return false }

            // Search match
            let matchesSearch = q.isEmpty ||
                service.title.localizedCaseInsensitiveContains(q) ||
                business.businessName.localizedCaseInsensitiveContains(q)

            // Category match: prefer service.category if present; fall back to title contains
            let matchesCategory: Bool = {
                if selectedCategory == "All" { return true }
                if let cat = service.category, !cat.isEmpty {
                    return cat.caseInsensitiveCompare(selectedCategory) == .orderedSame
                } else {
                    return service.title.localizedCaseInsensitiveContains(selectedCategory)
                }
            }()

            // Distance match (if both locations are available)
            if let userLoc, let bizLoc = business.location {
                let withinDistance = userLoc.distance(from: bizLoc) <= distanceFilterKm * 1000
                return matchesSearch && matchesCategory && withinDistance
            }

            // If no location info, allow but still require search/category match
            return matchesSearch && matchesCategory
        }
    }

    private func loadUserBookings() async throws -> [BookingModel] {
        guard let user = authVM.currentUser else { return [] }
        var query: Query
        if user.role == .homeowner {
            query = Firestore.firestore().collection("bookings").whereField("homeownerID", isEqualTo: user.id ?? "")
        } else {
            query = Firestore.firestore().collection("bookings").whereField("businessID", isEqualTo: user.businessID ?? "")
        }
        let snapshot = try await query.order(by: "date", descending: true).getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: BookingModel.self) }
    }
}

struct ServiceCardView: View {
    var service: ServiceModel
    var business: BusinessModel?

    var body: some View {
        NavigationLink(value: service) {
            VStack(alignment: .leading, spacing: 8) {
                if let imageURL = service.imageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                    }
                    .frame(height: 180)
                    .clipped()
                    .cornerRadius(10)
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.green.opacity(0.3))
                        .frame(height: 180)
                        .overlay(
                            Text(service.title)
                                .font(.title3)
                                .foregroundColor(.primary)
                                .padding()
                        )
                }

                Text(service.title)
                    .font(.headline)

                if let business = business {
                    Text("by \(business.businessName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Text("Price: $\(service.price, specifier: "%.2f")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct BookingCardView: View {
    var booking: BookingModel

    var body: some View {
        VStack(alignment: .leading) {
            Text(booking.service.title)
                .font(.headline)
            Text("Status: \(booking.status.rawValue.capitalized)")
                .font(.subheadline)
                .foregroundColor(.gray)
            Text("Scheduled for: \(booking.date.formatted(date: .abbreviated, time: .shortened))" + (booking.timeSlot != nil ? " at \(booking.timeSlot!)" : ""))
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .frame(maxWidth: .infinity)
    }
}

