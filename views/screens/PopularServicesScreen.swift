// PopularServicesScreen.swift

import SwiftUI
import CoreLocation

struct PopularServicesScreen: View {
    var services: [ServiceModel]
    var businesses: [BusinessModel]
    var userLocation: CLLocation?
    var maxDistanceKm: Double
    var currentUserID: String?

    var body: some View {
        Group {
            if filteredAndSortedServices.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                        .padding(.bottom, 10)
                    
                    Text("No popular services nearby.")
                        .font(.title3)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredAndSortedServices) { service in
                            if let business = businesses.first(where: { $0.id == service.businessID }) {
                                ServiceCardView(service: service, business: business)
                                    .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle("Popular Services")
        .applyAppBackground()
    }

    private var filteredAndSortedServices: [ServiceModel] {
        return services
            .filter { service in
                guard let business = businesses.first(where: { $0.id == service.businessID }),
                      let bizLocation = business.location,
                      let userLoc = userLocation else {
                    return false
                }

                // Exclude services from user's own business
                let isSupervisor = business.supervisorID == currentUserID
                let isMember = business.memberIDs.contains(currentUserID ?? "")
                if isSupervisor || isMember { return false }

                return userLoc.distance(from: bizLocation) <= maxDistanceKm * 1000
            }
            .sorted { ($0.bookingsCount ?? 0) > ($1.bookingsCount ?? 0) }
    }
}
