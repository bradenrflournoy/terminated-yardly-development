// BusinessProfileScreen.swift

import SwiftUI
import FirebaseFirestore

struct BusinessProfileScreen: View {
    let business: BusinessModel
    @EnvironmentObject var authVM: AuthViewModel
    @State private var services: [ServiceModel] = []
    @State private var isLoading = true
    @State private var currentLevel: String = ""
    @State private var earnedBadges: [String] = []
    @State private var chatPartner: UserModel?

    private let firestoreService = FirestoreService()

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 16) {
                // Header
                VStack(spacing: 8) {
                    if let imageURL = business.profileImageURL, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { image in
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 200)
                                .clipped()
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 200)
                        }
                    }
                    Text(business.businessName)
                        .font(.title)
                        .bold()
                    Text(business.businessType == .individual ? "Individual" : "Organization")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if business.bio != "" {
                        Text(business.bio)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
                Divider()
                
                // Only show if chatPartner is loaded
                if let chatPartner = chatPartner {
                    NavigationLink(value: chatPartner) {
                        Label("Message Business", systemImage: "message.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(Color("BGColor"))
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }

                // Level & Badges Section
                LevelAndBadgesView(level: currentLevel, badges: earnedBadges)

                // Services
                if isLoading {
                    ProgressView("Loading services...")
                        .padding()
                } else if services.isEmpty {
                    Text("This business hasn't added any services yet.")
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                } else {
                    VStack(spacing: 12) {
                        Text("Services")
                            .font(.title2)
                            .bold()
                            .padding(.horizontal)
                        ForEach(services) { service in
                            ServiceCardView(service: service, business: business)
                        }
                    }
                }

                // Reviews
                ReviewSummaryView(businessID: business.id ?? "")
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding()
        }
        .navigationTitle("Business Profile")
        .task {
            await loadServices()
            await loadLevelAndBadges()
            await loadChatPartner()  // <-- now fetched on appear
        }
        .applyAppBackground()
    }
    
    private func loadChatPartner() async {
        do {
            let managerDoc = try await Firestore.firestore()
                .collection("users")
                .document(business.managerID)
                .getDocument()
            chatPartner = try? managerDoc.data(as: UserModel.self)
        } catch {
            print("Failed to fetch business owner: \(error.localizedDescription)")
        }
    }

    private func loadServices() async {
        do {
            let all = try await firestoreService.fetchServices()
            services = all.filter { $0.businessID == business.id }
        } catch {
            print("Failed to load business services: \(error.localizedDescription)")
        }
        isLoading = false
    }

    private func loadLevelAndBadges() async {
        guard let businessID = business.id else { return }
        do {
            let doc = try await Firestore.firestore().collection("businesses").document(businessID).getDocument()
            let data = doc.data()
            currentLevel = String(data?["level"] as? Int ?? 0)
            earnedBadges = data?["badges"] as? [String] ?? []
        } catch {
            print("Failed to load level and badges: \(error.localizedDescription)")
        }
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
