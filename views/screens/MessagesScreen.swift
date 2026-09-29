// MessagesScreen.swift

import SwiftUI
import FirebaseFirestore

struct MessagesScreen: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var threads: [ChatThreadModel] = []
    @State private var partners: [String: UserModel] = [:]
    @State private var isLoading = true
    @State private var listener: ListenerRegistration?
    
    private let chatService = ChatService()
    private let db = Firestore.firestore()

    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading...").padding()
                } else if threads.isEmpty {
                    VStack {
                        Spacer()
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                            .padding(.bottom, 10)
                        Text("No messages yet")
                            .font(.title3)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                } else {
                    List(threads.sorted(by: { $0.lastMessageTimestamp > $1.lastMessageTimestamp })) { thread in
                        if let partner = partnerForThread(thread) {
                            NavigationLink(destination: ChatScreen(partner: partner)) {
                                HStack {
                                    if let imageURL = partner.profileImageURL, let url = URL(string: imageURL) {
                                        AsyncImage(url: url) { image in
                                            image.resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 40, height: 40)
                                                .clipShape(Circle())
                                        } placeholder: {
                                            Circle().frame(width: 40, height: 40)
                                                .foregroundColor(.gray.opacity(0.3))
                                        }
                                    }
                                    VStack(alignment: .leading) {
                                        Text(partner.name).font(.headline)
                                        Text(thread.lastMessage.isEmpty ? "[Image]" : thread.lastMessage)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if let count = thread.unreadCounts[authVM.currentUser?.id ?? ""], count > 0 {
                                        Text("\(count)")
                                            .font(.caption2)
                                            .padding(6)
                                            .background(Color.red)
                                            .foregroundColor(.white)
                                            .clipShape(Circle())
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.inline)
            .applyAppBackground()
        }
        .onAppear(perform: loadThreads)
        .onDisappear { listener?.remove() }
    }

    private func loadThreads() {
        guard let currentUserID = authVM.currentUser?.id else { isLoading = false; return }
        listener = chatService.streamThreads(for: currentUserID) { newThreads in
            self.threads = newThreads
            self.loadPartnersIfNeeded()
            self.isLoading = false
        }
    }

    private func loadPartnersIfNeeded() {
        let neededIDs = Set(threads.flatMap { $0.participants }).subtracting(Set(partners.keys))
        guard !neededIDs.isEmpty else { return }
        
        db.collection("users")
            .whereField(FieldPath.documentID(), in: Array(neededIDs))
            .getDocuments { snapshot, _ in
                let users = snapshot?.documents.compactMap { try? $0.data(as: UserModel.self) } ?? []
                for user in users { partners[user.id ?? ""] = user }
            }
    }

    private func partnerForThread(_ thread: ChatThreadModel) -> UserModel? {
        thread.participants.first(where: { $0 != authVM.currentUser?.id }).flatMap { partners[$0] }
    }
}
