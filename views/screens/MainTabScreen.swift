// MainTabScreen.swift

import SwiftUI
import FirebaseFirestore

struct MainTabScreen: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var selectedTab = 0
    @StateObject private var locationManager: LocationManagerWrapper
    @State private var supervisorHasActiveJob = false
    @State private var business: BusinessModel? = nil

    private let firestoreService = FirestoreService()

    init() {
        _locationManager = StateObject(wrappedValue: LocationManagerWrapper(userID: nil))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeScreen()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(0)

            MessagesScreen()
                .tabItem {
                    Label("Messages", systemImage: "message")
                }
                .tag(1)

            roleBasedThirdTab()
                .tabItem {
                    Label(thirdTabLabel, systemImage: thirdTabIcon)
                }
                .tag(2)

            AccountScreen()
                .tabItem {
                    Label("Account", systemImage: "person")
                }
                .tag(3)
        }
        .onAppear {
            if authVM.currentUser?.role == .teen {
                locationManager.start(userID: authVM.currentUser?.id)
            }
            if authVM.currentUser?.role == .supervisor {
                checkForActiveJob()
            }
        }
        .onDisappear {
            locationManager.stop()
        }
    }

    @ViewBuilder
    private func roleBasedThirdTab() -> some View {
        switch authVM.currentUser?.role {
        case .teen:
            Group {
                if let business {
                    if business.hasCompletedOnboarding {
                        BusinessScreen()
                    } else {
                        BusinessOnboardingScreen(business: business) {
                            Task { await loadBusiness() }
                        }
                    }
                } else {
                    ProgressView("Loading...")
                        .onAppear {
                            Task { await loadBusiness() }
                        }
                }
            }

        case .supervisor:
            SuperviseScreen()

        case .homeowner:
            NavigationView {
                LockedScreen(reason: "Create a business to access this tab.")
            }

        default:
            EmptyView()
        }
    }

    private var thirdTabLabel: String {
        switch authVM.currentUser?.role {
        case .teen: return "Business"
        case .supervisor: return supervisorHasActiveJob ? "Tracking" : "Supervise"
        case .homeowner: return "Locked"
        default: return ""
        }
    }

    private var thirdTabIcon: String {
        switch authVM.currentUser?.role {
        case .teen: return "briefcase"
        case .supervisor: return supervisorHasActiveJob ? "location" : "person.3"
        case .homeowner: return "lock"
        default: return "questionmark"
        }
    }

    private func checkForActiveJob() {
        guard let businessID = authVM.currentUser?.businessID else { return }
        let db = Firestore.firestore()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? Date()

        db.collection("bookings")
            .whereField("businessID", isEqualTo: businessID)
            .whereField("status", isEqualTo: "scheduled")
            .whereField("date", isGreaterThanOrEqualTo: Timestamp(date: startOfToday))
            .whereField("date", isLessThan: Timestamp(date: endOfToday))
            .getDocuments { snapshot, _ in
                supervisorHasActiveJob = snapshot?.documents.isEmpty == false
            }
    }

    private func loadBusiness() async {
        guard let userID = authVM.currentUser?.id else { return }
        do {
            let fetchedBusiness = try await firestoreService.fetchBusinessByMember(userID)
            await MainActor.run {
                self.business = fetchedBusiness
            }
        } catch {
            print("Failed to load business: \(error)")
        }
    }
}

class LocationManagerWrapper: ObservableObject {
    private var manager: LocationManager?

    init(userID: String?) {
        if let userID = userID {
            self.manager = LocationManager(userID: userID)
        }
    }

    func start(userID: String?) {
        guard manager == nil, let userID = userID else { return }
        manager = LocationManager(userID: userID)
    }

    func stop() {
        manager?.stopUpdating()
        manager = nil
    }
}
