// SuperviseScreen.swift

import SwiftUI
import FirebaseFirestore
#if canImport(FirebaseFirestoreSwift)
import FirebaseFirestoreSwift   // works on your friend’s older toolchain
#endif
import CoreLocation

struct SuperviseScreen: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var teenUsers: [UserModel] = []
    @State private var selectedTeen: UserModel?
    @State private var business: BusinessModel?
    @State private var services: [ServiceModel] = []
    @State private var bookings: [BookingModel] = []
    @State private var activeBooking: BookingModel?
    @State private var isLoading = true
    @State private var locationListener: ListenerRegistration?
    @State private var showAddBusiness = false
    @State private var showStopConfirm = false

    private let firestoreService = FirestoreService()
    private let db = Firestore.firestore()

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                if isLoading {
                    ProgressView("Loading...")
                        .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            if teenUsers.isEmpty {
                                Text("You’re not supervising any businesses yet.")
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                                    .padding(.bottom)
                                
                                Button {
                                    showAddBusiness = true
                                } label: {
                                    Label("Add Business", systemImage: "plus")
                                        .buttonStyle(filled: .accentColor)
                                        .frame(maxWidth: .infinity)
                                        .padding(.horizontal)
                                }
                            } else {
                                Picker("Select Teen", selection: $selectedTeen) {
                                    ForEach(teenUsers) { teen in
                                        Text(teen.name).tag(Optional(teen))
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .padding(.horizontal)
                                
                                Button("Add Another Business") {
                                    showAddBusiness = true
                                }
                                .buttonStyle(.bordered)
                                .foregroundColor(Color.accentColor)
                            }
                            
                            if let teen = selectedTeen {
                                let teenBookings = bookings.filter { $0.businessID == teen.businessID }
                                
                                SupervisedTeenDetails(teen: teen, business: business, services: services, bookings: teenBookings, onApprove: updateApproval)
                                
                                if let active = teenBookings.first(where: { $0.status == .inProgress }), let teen = selectedTeen {
                                    NavigationLink(destination: TrackingScreen(booking: active, teen: teen)) {
                                        Label("Track Active Job", systemImage: "location.circle.fill")
                                            .padding()
                                            .frame(maxWidth: .infinity)
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .cornerRadius(10)
                                            .padding(.horizontal)
                                    }
                                    .padding(.top)
                                }
                            }
                            
                            NavigationLink(destination: ActiveJobsScreen()) {
                                Label("View Active Jobs", systemImage: "briefcase.fill")
                                    .buttonStyle(filled: .orange)
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal)
                            }
                            
                            if selectedTeen != nil {
                                Button(role: .destructive) {
                                    showStopConfirm = true
                                } label: {
                                    Label("Stop Supervising", systemImage: "xmark.circle.fill")
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color(.systemGray6))
                                        .foregroundColor(.red)
                                        .cornerRadius(10)
                                        .padding(.horizontal)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Supervise")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showAddBusiness) {
                AddBusinessByCodeWindow()
            }
            .applyAppBackground()
        }
        .onAppear {
            if teenUsers.isEmpty {
                loadSupervisedData()
            }
        }
        .onDisappear {
            locationListener?.remove()
        }
        .alert("Stop supervising this business?", isPresented: $showStopConfirm) {
            Button("Yes, Remove", role: .destructive) {
                Task {
                    await removeSupervisedBusiness()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .onChange(of: selectedTeen) { newTeen in
            Task {
                await loadTeenBusinessAndServices(for: newTeen)
            }
        }
    }

    private func loadSupervisedData() {
        guard let user = authVM.currentUser else {
            isLoading = false
            return
        }

        Task {
            isLoading = true
            do {
                let supervisedIDs = user.supervisedBusinessIDs ?? []
                var allTeens: [UserModel] = []
                var allBookings: [BookingModel] = []
                var allServices: [ServiceModel] = []

                // Fetch without clearing visible data
                for businessID in supervisedIDs {
                    let businessDoc = try await db.collection("businesses").document(businessID).getDocument()
                    if let business = try? businessDoc.data(as: BusinessModel.self) {
                        let memberIDs = business.memberIDs
                        let memberSnapshots = try await db.collection("users")
                            .whereField(FieldPath.documentID(), in: memberIDs)
                            .getDocuments()
                        let members = try memberSnapshots.documents.compactMap { try $0.data(as: UserModel.self) }
                        allTeens.append(contentsOf: members)
                    }

                    let bookingQuery = try await db.collection("bookings")
                        .whereField("businessID", isEqualTo: businessID)
                        .getDocuments()
                    let bookings = try bookingQuery.documents.compactMap { try $0.data(as: BookingModel.self) }
                    allBookings.append(contentsOf: bookings)

                    let serviceList = try await firestoreService.fetchServices()
                    let filtered = serviceList.filter { $0.businessID == businessID }
                    allServices.append(contentsOf: filtered)
                }

                // Only replace at the end
                await MainActor.run {
                    teenUsers = allTeens
                    selectedTeen = allTeens.first
                    bookings = allBookings
                    services = allServices
                    if let selected = allTeens.first, let bizID = selected.businessID {
                        Task {
                            let bizSnap = try await db.collection("businesses").document(bizID).getDocument()
                            business = try bizSnap.data(as: BusinessModel.self)
                        }
                    }
                }
            } catch {
                print("Error loading supervised data: \(error.localizedDescription)")
            }
            isLoading = false
        }
    }

    private func updateApproval(for booking: BookingModel, approved: Bool) async {
        guard let id = booking.id else { return }
        do {
            try await db.collection("bookings").document(id).updateData([
                "isApproved": approved,
                "status": approved ? BookingStatus.scheduled.rawValue : BookingStatus.cancelled.rawValue
            ])
            loadSupervisedData()
        } catch {
            print("Error updating approval: \(error.localizedDescription)")
        }
    }
    
    private func removeSupervisedBusiness() async {
        guard let supervisorID = authVM.currentUser?.id,
              let businessID = selectedTeen?.businessID else { return }

        let db = Firestore.firestore()
        let userRef = db.collection("users").document(supervisorID)
        let businessRef = db.collection("businesses").document(businessID)

        do {
            let snapshot = try await userRef.getDocument()

            if var list = snapshot.data()?["supervisedBusinessIDs"] as? [String],
               let index = list.firstIndex(of: businessID) {
                list.remove(at: index)
                try await userRef.updateData(["supervisedBusinessIDs": list])

                // Remove supervisorID from the business document
                try await businessRef.updateData(["supervisorID": FieldValue.delete()])

                // Reflect change locally
                try await authVM.refreshCurrentUser()
                await MainActor.run {
                    loadSupervisedData()
                }
            }
        } catch {
            print("Failed to remove supervision: \(error.localizedDescription)")
        }
    }
    
    private func loadTeenBusinessAndServices(for teen: UserModel?) async {
        guard let teen = teen, let businessID = teen.businessID else {
            business = nil
            services = []
            return
        }

        do {
            let bizSnap = try await db.collection("businesses").document(businessID).getDocument()
            business = try bizSnap.data(as: BusinessModel.self)

            let allServices = try await firestoreService.fetchServices()
            services = allServices.filter { $0.businessID == businessID }
        } catch {
            print("Error loading teen's business/services: \(error.localizedDescription)")
            business = nil
            services = []
        }
    }
}

struct SupervisedTeenDetails: View {
    var teen: UserModel
    var business: BusinessModel?
    var services: [ServiceModel]
    var bookings: [BookingModel]
    var onApprove: (BookingModel, Bool) async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Supervising:")
                    .font(.title2)
                    .bold()
                Spacer()
                Text(teen.name)
                    .font(.title2)
                    .bold()
            }
            
            Divider()

            if let business = business {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Business Info")
                        .font(.headline)

                    HStack {
                        Text("Name:")
                        Spacer()
                        Text(business.businessName)
                    }

                    HStack {
                        Text("Level:")
                        Spacer()
                        Text("\(business.level)")
                    }

                    HStack {
                        Text("Cancellations:")
                        Spacer()
                        Text("\(business.cancellationCount)")
                    }
                }
            }
            
            Divider()

            if !services.isEmpty {
                VStack(alignment: .leading) {
                    Text("Services")
                        .font(.headline)
                    ForEach(services) { service in
                        HStack {
                            Text(service.title)
                                .font(.headline)
                            Spacer()
                            Text("$\(service.price, specifier: "%.2f")")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                }
            }

            let pending = bookings.filter { $0.status == .pendingApproval }
            if !pending.isEmpty {
                VStack(alignment: .leading) {
                    Text("Pending Approvals").font(.headline)
                    ForEach(pending) { booking in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(booking.service.title).font(.subheadline)
                            Text("Date: \(booking.date.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                            if let location = booking.locationDescription, !location.isEmpty {
                                Text("Location: \(location)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            HStack {
                                Button("Approve") {
                                    Task { await onApprove(booking, true) }
                                }
                                .foregroundColor(.green)

                                Button("Decline") {
                                    Task { await onApprove(booking, false) }
                                }
                                .foregroundColor(.red)
                            }
                        }
                        .padding()
                        .background(Color.yellow.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
            }

            let history = bookings.filter { $0.status != .pendingApproval }
            if !history.isEmpty {
                VStack(alignment: .leading) {
                    Text("Job History").font(.headline)
                    ForEach(history) { booking in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(booking.service.title).font(.subheadline)
                            Text("Status: \(booking.status.rawValue.capitalized)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(booking.date.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            if let location = booking.locationDescription, !location.isEmpty {
                                Text("Location: \(location)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray5))
                        .cornerRadius(10)
                    }
                }
            }
        }
        .padding()
    }
}
