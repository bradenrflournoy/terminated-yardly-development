// BusinessScreen.swift

import SwiftUI
import Charts
import FirebaseFirestore

struct BusinessScreen: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.horizontalSizeClass) var sizeClass
    @State private var showNewService = false
    @State private var showEditService = false
    @State private var selectedService: ServiceModel? = nil
    @State private var services: [ServiceModel] = []
    @State private var isLoading = true
    @State private var navigateToSettings = false
    @State private var currentLevel: String = ""
    @State private var earnedBadges: [String] = []
    @State private var businessStats: BusinessStats? = nil
    @State private var path = NavigationPath()
    @State private var businessName: String = ""
    @State private var businessNameListener: ListenerRegistration? = nil
    @State private var supervisionRequests: [SupervisionRequestModel] = []
    @State private var selectedRequest: SupervisionRequestModel?
    @State private var showSupervisionApprovalDialog = false
    @State private var businessType: BusinessType = .individual
    @State private var membershipRequests: [MembershipRequestModel] = []
    @State private var selectedMembershipRequest: MembershipRequestModel?
    @State private var showMembershipApprovalDialog = false
    @State private var isManager: Bool? = nil
    @State private var showDeleteConfirmation = false
    @State private var serviceToDelete: ServiceModel?
    
    private let firestoreService = FirestoreService()
    
    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 16) {
                    Group {
                        Text(businessName.isEmpty ? "Your Business" : businessName)
                            .font(.title)
                            .bold()
                        
                        Text(
                            businessType == .individual
                            ? "Individual"
                            : "Organization" + ((isManager ?? false) ? " | Manager" : " | Member")
                        )
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                    
                    if !supervisionRequests.isEmpty && isManager == true {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("📩 Supervision Requests")
                                .font(.headline)
                                .padding(.top)
                            
                            ForEach(supervisionRequests) { request in
                                Button {
                                    selectedRequest = request
                                    showSupervisionApprovalDialog = true
                                } label: {
                                    HStack {
                                        Image(systemName: "person.crop.circle.badge.plus")
                                        Text("Request from \(request.supervisorName)")
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.red.opacity(0.2))
                                    .cornerRadius(10)
                                }
                            }
                        }
                    }

                    Group {
                        if !membershipRequests.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("👥 Membership Requests").font(.headline)
                                
                                ForEach(membershipRequests) { request in
                                    Button {
                                        selectedMembershipRequest = request
                                        showMembershipApprovalDialog = true
                                    } label: {
                                        HStack {
                                            Image(systemName: "person.crop.circle.badge.questionmark")
                                            Text("Request from \(request.userName)")
                                        }
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(Color.red.opacity(0.2))
                                        .cornerRadius(10)
                                    }
                                }
                            }
                        }
                        
                        Divider()
                        
                        Group {
                            if let stats = businessStats {
                                BusinessPerformanceView(stats: stats)
                                BusinessLifetimeView(stats: stats)
                            } else {
                                BusinessPerformancePlaceholderView()
                                BusinessLifetimePlaceholderView()
                            }
                            
                            if !currentLevel.isEmpty || !earnedBadges.isEmpty {
                                LevelAndBadgesView(level: currentLevel, badges: earnedBadges)
                            } else {
                                LevelPlaceholderView()
                            }
                        }
                        
                        Text("Services")
                            .font(.title2)
                            .bold()
                        
                        if isLoading {
                            ProgressView("Loading services...")
                                .padding()
                        } else if services.isEmpty {
                            Text("You haven't added any services yet.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        } else {
                            let columns = [GridItem(.adaptive(minimum: 300, maximum: 500))]
    
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(services) { service in
                                    VStack(alignment: .leading, spacing: 8) {
                                        if let imageURL = service.imageURL, let url = URL(string: imageURL) {
                                            AsyncImage(url: url) { image in
                                                image.resizable().scaledToFill()
                                            } placeholder: {
                                                Rectangle().fill(Color.gray.opacity(0.2))
                                            }
                                            .frame(height: 120)
                                            .clipped()
                                            .cornerRadius(8)
                                        } else {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.green.opacity(0.3))
                                                .frame(height: 120)
                                                .overlay(
                                                    Text(service.title)
                                                        .font(.headline)
                                                        .multilineTextAlignment(.center)
                                                        .padding()
                                                )
                                        }
    
                                        Text(service.title)
                                            .font(.headline)
    
                                        Text("Price: $\(service.price, specifier: "%.2f")")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
    
                                        HStack {
                                            Button("Edit") {
                                                selectedService = service
                                                showEditService = true
                                            }
    
                                            Spacer()
    
                                            Button(role: .destructive) {
                                                serviceToDelete = service
                                                showDeleteConfirmation = true
                                            } label: {
                                                Image(systemName: "trash")
                                            }
                                        }
                                        .font(.caption)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        if let businessID = authVM.currentUser?.businessID {
                            ReviewSummaryView(businessID: businessID)
                        }
                        
                        actionButtonsView
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Business")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: String.self) { route in
                switch route {
                case "settings":
                    BusinessSettingsScreen().environmentObject(authVM)
                default:
                    EmptyView()
                }
            }
            .applyAppBackground()
        }
        .onAppear {
            Task {
                async let servicesTask: () = loadServices()
                async let infoTask: () = loadBusinessInfo()
                async let managerTask: () = checkIfUserIsManager()
                async let supTask: () = fetchSupervisionRequests()
                async let memTask: () = fetchMembershipRequests()
                
                _ = await (servicesTask, infoTask, managerTask, supTask, memTask)
            }
            
            if let businessID = authVM.currentUser?.businessID {
                listenToBusinessNameChanges(businessID: businessID)
            }
        }
        .onDisappear {
            businessNameListener?.remove()
            businessNameListener = nil
        }
        .sheet(isPresented: $showNewService, onDismiss: {
            Task { await loadServices() }
        }) {
            NewServiceWindow().environmentObject(authVM)
        }
        .sheet(item: $selectedService, onDismiss: {
            Task { await loadServices() }
        }) { service in
            EditServiceWindow(service: service).environmentObject(authVM)
        }
        .alert("Approve Supervision?", isPresented: $showSupervisionApprovalDialog) {
            Button("Approve", role: .destructive) {
                if let req = selectedRequest {
                    Task {
                        await handleSupervisionApproval(request: req, approved: true)
                        await fetchSupervisionRequests()
                        selectedRequest = nil
                    }
                }
            }
            
            Button("Reject", role: .cancel) {
                if let req = selectedRequest {
                    Task {
                        await handleSupervisionApproval(request: req, approved: false)
                        await fetchSupervisionRequests()
                        selectedRequest = nil
                    }
                }
            }
        } message: {
            Text("Allow this supervisor to monitor your business?")
        }
        .alert("Approve Membership?", isPresented: $showMembershipApprovalDialog) {
            Button("Approve", role: .destructive) {
                if let req = selectedMembershipRequest {
                    Task {
                        await handleMembershipApproval(request: req, approved: true)
                        await fetchMembershipRequests()
                        selectedMembershipRequest = nil
                    }
                }
            }
            
            Button("Reject", role: .cancel) {
                if let req = selectedMembershipRequest {
                    Task {
                        await handleMembershipApproval(request: req, approved: false)
                        await fetchMembershipRequests()
                        selectedMembershipRequest = nil
                    }
                }
            }
        } message: {
            Text("Allow this teen to join your business?")
        }
        .alert("Delete Service?", isPresented: $showDeleteConfirmation, presenting: serviceToDelete) { service in
            Button("Delete", role: .destructive) {
                if let index = services.firstIndex(where: { $0.id == service.id }) {
                    deleteService(at: IndexSet(integer: index))
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { service in
            Text("Are you sure you want to delete '\(service.title)'?")
        }
    }
    
    private func loadServices() async {
        guard let businessID = authVM.currentUser?.businessID else {
            await MainActor.run {
                services = []
                isLoading = false
            }
            return
        }
        
        do {
            let allServices = try await firestoreService.fetchServices()
            let filtered = allServices.filter { $0.businessID == businessID }
            await MainActor.run {
                services = filtered
                isLoading = false
            }
        } catch {
            print("Error fetching services: \(error.localizedDescription)")
            await MainActor.run {
                services = []
                isLoading = false
            }
        }
    }
    
    private func deleteService(at offsets: IndexSet) {
        for index in offsets {
            if let id = services[index].id {
                Task {
                    try? await firestoreService.deleteService(id: id)
                    await loadServices()
                }
            }
        }
    }
    
    private func loadBusinessInfo() async {
        guard let businessID = authVM.currentUser?.businessID else { return }
        
        async let statsTask: BusinessStats? = try? await firestoreService.getBusinessStats(businessID: businessID)
        async let businessDocTask = Firestore.firestore().collection("businesses").document(businessID).getDocument()
        
        let (stats, businessDoc) = await (statsTask, try? await businessDocTask)
        self.businessStats = stats
        
        guard let data = businessDoc?.data() else { return }
        
        // Pull level and badges from Firestore
        currentLevel = String(data["level"] as? Int ?? 0)
        earnedBadges = data["badges"] as? [String] ?? []
        
        if let name = data["businessName"] as? String {
            businessName = name
        }
        
        if let typeString = data["businessType"] as? String,
           let type = BusinessType(rawValue: typeString) {
            businessType = type
        }
    }
    
    private func listenToBusinessNameChanges(businessID: String) {
        businessNameListener?.remove()
        businessNameListener = Firestore.firestore()
            .collection("businesses")
            .document(businessID)
            .addSnapshotListener { snapshot, error in
                if let data = snapshot?.data(), let updatedName = data["businessName"] as? String {
                    businessName = updatedName
                }
            }
    }
    
    private func fetchSupervisionRequests() async {
        guard let businessID = authVM.currentUser?.businessID else { return }
        
        do {
            let snapshot = try await Firestore.firestore()
                .collection("supervisionRequests")
                .whereField("businessID", isEqualTo: businessID)
                .whereField("status", isEqualTo: "pending")
                .getDocuments()
            
            supervisionRequests = try snapshot.documents.compactMap {
                try $0.data(as: SupervisionRequestModel.self)
            }
        } catch {
            print("Error fetching supervision requests: \(error.localizedDescription)")
        }
    }
    
    private func handleSupervisionApproval(request: SupervisionRequestModel, approved: Bool) async {
        let db = Firestore.firestore()
        let requestRef = db.collection("supervisionRequests").document(request.id ?? "")
        let businessRef = db.collection("businesses").document(request.businessID)

        do {
            if approved {
                // 1. Add to supervisor’s list
                let supervisorRef = db.collection("users").document(request.supervisorID)
                let userSnapshot = try await supervisorRef.getDocument()
                
                if var currentList = userSnapshot.data()?["supervisedBusinessIDs"] as? [String] {
                    if !currentList.contains(request.businessID) {
                        currentList.append(request.businessID)
                        try await supervisorRef.updateData(["supervisedBusinessIDs": currentList])
                    }
                } else {
                    try await supervisorRef.updateData(["supervisedBusinessIDs": [request.businessID]])
                }

                // 2. Set supervisorID in the business document
                try await businessRef.updateData(["supervisorID": request.supervisorID])

            } else {
                // If rejected, ensure it's removed from the business doc
                try await businessRef.updateData(["supervisorID": FieldValue.delete()])
            }

            try await requestRef.updateData(["status": approved ? "approved" : "rejected"])

        } catch {
            print("Error updating request: \(error.localizedDescription)")
        }
    }
    
    private func fetchMembershipRequests() async {
        guard let businessID = authVM.currentUser?.businessID,
              let currentUserID = authVM.currentUser?.id else { return }
        
        do {
            let businessDoc = try await Firestore.firestore().collection("businesses").document(businessID).getDocument()
            if let managerID = businessDoc.data()?["managerID"] as? String, managerID == currentUserID {
                let snapshot = try await Firestore.firestore()
                    .collection("membershipRequests")
                    .whereField("businessID", isEqualTo: businessID)
                    .whereField("status", isEqualTo: "pending")
                    .getDocuments()
                
                membershipRequests = try snapshot.documents.compactMap {
                    try $0.data(as: MembershipRequestModel.self)
                }
            }
        } catch {
            print("Failed to fetch membership requests: \(error)")
        }
    }
    
    private func handleMembershipApproval(request: MembershipRequestModel, approved: Bool) async {
        let db = Firestore.firestore()
        let requestRef = db.collection("membershipRequests").document(request.id!)
        
        do {
            try await requestRef.updateData(["status": approved ? "approved" : "rejected"])
            
            if approved {
                let businessRef = db.collection("businesses").document(request.businessID)
                let userRef = db.collection("users").document(request.userID)
                
                // Fetch current memberIDs to determine businessType
                let businessDoc = try await businessRef.getDocument()
                var memberIDs = businessDoc.data()?["memberIDs"] as? [String] ?? []
                memberIDs.append(request.userID)
                
                try await businessRef.updateData([
                    "memberIDs": FieldValue.arrayUnion([request.userID]),
                    "businessType": (memberIDs.count > 1 ? BusinessType.organization.rawValue : BusinessType.individual.rawValue)
                ])
                
                try await userRef.updateData([
                    "businessID": request.businessID,
                    "role": UserRole.teen.rawValue,
                    "pendingBusinessMembership": FieldValue.delete()
                ])
            }
        } catch {
            print("Failed to update membership request: \(error)")
        }
    }
    
    private func checkIfUserIsManager() async {
        guard let user = authVM.currentUser, let businessID = user.businessID else { return }
        
        do {
            let doc = try await Firestore.firestore().collection("businesses").document(businessID).getDocument()
            let managerID = doc["managerID"] as? String
            isManager = (managerID == user.id)
        } catch {
            print("Failed to determine manager status: \(error)")
            isManager = false
        }
    }
    
    // Extracted from ActionButtons() to a computed property to avoid scope issues
    private var actionButtonsView: some View {
        VStack(spacing: 10) {
            Button {
                showNewService = true
            } label: {
                Label("Add New Service", systemImage: "plus")
                    .buttonStyle(filled: .accentColor)
            }
            .disabled(!(isManager ?? false))

            Button {
                path.append("settings")
            } label: {
                Label("Business Settings", systemImage: "gear")
                    .buttonStyle(filled: .accentColor)
            }

            NavigationLink(destination: ActiveJobsScreen()) {
                Label("View Active Jobs", systemImage: "briefcase.fill")
                    .buttonStyle(filled: .orange)
            }
        }
        .padding(.horizontal)
        .task {
            await checkIfUserIsManager()
        }
    }
}

// MARK: - Subviews

private struct BusinessPerformancePlaceholderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("💰 Performance")
                .font(.headline)
                .redacted(reason: .placeholder)

            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 100)
                .cornerRadius(8)
                .redacted(reason: .placeholder)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(10)
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
    }
}

private struct BusinessLifetimePlaceholderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("🧰 Lifetime")
                .font(.headline)
                .redacted(reason: .placeholder)

            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 100)
                .cornerRadius(8)
                .redacted(reason: .placeholder)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(10)
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
    }
}

private struct LevelPlaceholderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("🎖 Level & Badges")
                .font(.headline)
                .redacted(reason: .placeholder)

            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 100)
                .cornerRadius(8)
                .redacted(reason: .placeholder)
        }
        .padding()
        .background(Color.yellow.opacity(0.2))
        .cornerRadius(10)
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
    }
}

private struct BusinessPerformanceView: View {
    let stats: BusinessStats

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("📊 Performance (Last 30 Days)").font(.headline)

            if stats.totalJobs == 0 {
                VStack {
                    Spacer()
                    Image(systemName: "chart.bar.xaxis")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.gray)
                        .padding(.bottom, 8)

                    Text("No performance stats yet")
                        .foregroundColor(.gray)
                        .font(.subheadline)
                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                VStack {
                    statsSummary
                    revenueChart
                    bookingChart
                    DonutChartView(entries: stats.repeatBreakdown)
                        .frame(height: 200)
                    progressSection
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(10)
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
    }

    private var statsSummary: some View {
        Group {
            Text("• New Bookings: \(stats.recentBookings)")
            Text("• Revenue: $\(stats.recentRevenue, specifier: "%.2f")")
            Text("• Cancellation Rate: \(stats.recentCancellationRate, specifier: "%.0f")%")
            Text("• Repeat Clients: \(stats.recentRepeatClients)")
        }
    }

    private var revenueChart: some View {
        Chart {
            ForEach(stats.revenueTrend, id: \.date) {
                LineMark(x: .value("Date", $0.date), y: .value("Revenue", $0.value))
            }
        }
        .frame(height: 150)
    }

    private var bookingChart: some View {
        Chart {
            ForEach(stats.bookingTrend, id: \.date) {
                BarMark(x: .value("Date", $0.date), y: .value("Bookings", $0.value))
            }
        }
        .frame(height: 150)
    }

    private var progressSection: some View {
        VStack(alignment: .leading) {
            Text("Progress to Next Badge")
            ProgressView(value: stats.progressTowardNextBadge)
                .padding()
        }
    }
}

private struct BusinessLifetimeView: View {
    let stats: BusinessStats

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("📈 Lifetime Stats").font(.headline)

            if stats.totalJobs == 0 {
                VStack {
                    Spacer()
                    Image(systemName: "clock.arrow.circlepath")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.gray)
                        .padding(.bottom, 8)

                    Text("No lifetime stats yet")
                        .foregroundColor(.gray)
                        .font(.subheadline)
                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                VStack {
                    Group {
                        Text("• Total Jobs: \(stats.totalJobs)")
                        Text("• Total Revenue: $\(stats.totalRevenue, specifier: "%.2f")")
                        Text("• Repeat Client Rate: \(stats.repeatClientRate, specifier: "%.0f")%")
                        Text("• Joined: \(stats.joinDate.formatted(date: .abbreviated, time: .omitted))")
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(10)
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
    }
}

private struct LevelAndBadgesView: View {
    let level: String
    let badges: [String]

    private let columns = [
        GridItem(.flexible(), alignment: .leading),
        GridItem(.flexible(), alignment: .leading)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with Level on left, Badges count on right
            HStack {
                Text("⭐ Level \(level)")
                    .font(.headline)

                Spacer()

                Text("\(badges.count) Badges 🎖")
                    .font(.headline)
            }

            if badges.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "star.slash")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.gray)
                        .padding(.bottom, 8)

                    Text("No badges yet")
                        .foregroundColor(.gray)
                        .font(.subheadline)
                    Spacer()
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(badges, id: \.self) { badge in
                        Text("• \(badge)")
                            .font(.footnote)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.2))
        .cornerRadius(10)
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
    }
}

// MARK: - Extensions

extension View {
    func buttonStyle(filled color: Color) -> some View {
        self
            .padding()
            .frame(maxWidth: .infinity)
            .background(color)
            .foregroundColor(Color("BGColor"))
            .cornerRadius(10)
    }
}

extension FirestoreService {
    func getBusinessStats(businessID: String) async throws -> BusinessStats {
        let bookingsRef = Firestore.firestore().collection("bookings")
        let businessRef = Firestore.firestore().collection("businesses").document(businessID)

        let now = Date()
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now

        let snapshot = try await bookingsRef
            .whereField("businessID", isEqualTo: businessID)
            .getDocuments()

        let bookings = snapshot.documents.compactMap { try? $0.data(as: BookingModel.self) }
        let recentBookings = bookings.filter { $0.date >= thirtyDaysAgo }

        var revenueByDay: [Date: Double] = [:]
        var bookingsByDay: [Date: Int] = [:]
        var clientBookings: [String: Int] = [:]

        var totalRevenue: Double = 0
        var totalJobs = 0
        var totalCancellations = 0

        for booking in bookings {
            let day = calendar.startOfDay(for: booking.date)
            totalJobs += 1

            if booking.status == .cancelled {
                totalCancellations += 1
                continue
            }

            let amount = booking.service.price
            totalRevenue += amount

            if booking.date >= thirtyDaysAgo {
                revenueByDay[day, default: 0] += amount
                bookingsByDay[day, default: 0] += 1
            }

            clientBookings[booking.homeownerID, default: 0] += 1
        }

        let repeatClients = clientBookings.values.filter { $0 > 1 }.count
        let totalClients = clientBookings.count
        let recentRepeatClients = recentBookings.map { $0.homeownerID }.filter { id in
            clientBookings[id, default: 0] > 1
        }.uniqued().count

        let revenueTrend = revenueByDay.map { TrendEntry(date: $0.key, value: $0.value) }
            .sorted { $0.date < $1.date }
        let bookingTrend = bookingsByDay.map { TrendEntry(date: $0.key, value: Double($0.value)) }
            .sorted { $0.date < $1.date }

        let repeatBreakdown = [
            DonutEntry(label: "Repeat", value: Double(repeatClients)),
            DonutEntry(label: "New", value: Double(totalClients - repeatClients))
        ]

        let joinSnapshot = try await businessRef.getDocument()
        let joinDate = (try? joinSnapshot.data(as: BusinessModel.self))?.joinDate ?? Date()

        let progress = min(Double(totalJobs) / 20.0, 1.0) // Example logic

        return BusinessStats(
            recentBookings: recentBookings.count,
            recentRevenue: recentBookings.reduce(0) { $0 + $1.service.price },
            recentCancellationRate: recentBookings.isEmpty ? 0 : Double(recentBookings.filter { $0.status == .cancelled }.count) / Double(recentBookings.count) * 100,
            recentRepeatClients: recentRepeatClients,
            totalJobs: totalJobs,
            totalRevenue: totalRevenue,
            repeatClientRate: totalClients == 0 ? 0 : Double(repeatClients) / Double(totalClients) * 100,
            joinDate: joinDate,
            revenueTrend: revenueTrend,
            bookingTrend: bookingTrend,
            repeatBreakdown: repeatBreakdown,
            progressTowardNextBadge: progress
        )
    }
}

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen: Set<Element> = []
        return filter { seen.insert($0).inserted }
    }
}

struct BusinessStats {
    let recentBookings: Int
    let recentRevenue: Double
    let recentCancellationRate: Double
    let recentRepeatClients: Int
    let totalJobs: Int
    let totalRevenue: Double
    let repeatClientRate: Double
    let joinDate: Date
    let revenueTrend: [TrendEntry]
    let bookingTrend: [TrendEntry]
    let repeatBreakdown: [DonutEntry]
    let progressTowardNextBadge: Double
}

struct TrendEntry {
    let date: Date
    let value: Double
}

struct DonutEntry: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
}

struct DonutChartView: View {
    let entries: [DonutEntry]

    var body: some View {
        GeometryReader { geometry in
            let total = entries.map { $0.value }.reduce(0, +)
            let radius = min(geometry.size.width, geometry.size.height) / 2
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

            ZStack {
                ForEach(entries) { entry in
                    let startAngle = angle(for: entry.label, in: entries, total: total)
                    let endAngle = startAngle + 360 * (entry.value / total)

                    PieSlice(startAngle: Angle(degrees: startAngle),
                             endAngle: Angle(degrees: endAngle),
                             center: center,
                             radius: radius)
                    .fill(color(for: entry.label))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func angle(for label: String, in entries: [DonutEntry], total: Double) -> Double {
        var angle: Double = -90
        for entry in entries {
            if entry.label == label { return angle }
            angle += 360 * (entry.value / total)
        }
        return angle
    }

    private func color(for label: String) -> Color {
        switch label {
        case "Repeat": return .green
        case "New": return .blue
        default: return .gray
        }
    }
}

// Helper Shape
struct PieSlice: Shape {
    var startAngle: Angle
    var endAngle: Angle
    var center: CGPoint
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: center)
        path.addArc(center: center,
                    radius: radius,
                    startAngle: startAngle,
                    endAngle: endAngle,
                    clockwise: false)
        return path
    }
}

