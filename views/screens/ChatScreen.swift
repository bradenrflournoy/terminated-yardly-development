// ChatScreen.swift

import SwiftUI
import PhotosUI
import FirebaseFirestore

struct ChatMessageRow: View {
    let message: MessageModel
    let isCurrentUser: Bool

    var body: some View {
        HStack {
            if isCurrentUser { Spacer() }
            VStack(alignment: .leading, spacing: 4) {
                if let imageURL = message.imageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { image in
                        image.resizable()
                            .scaledToFit()
                            .frame(maxWidth: 200)
                            .cornerRadius(10)
                    } placeholder: { ProgressView() }
                } else if !message.text.isEmpty {
                    Text(message.text)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                }

                Text(message.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2).foregroundColor(.secondary)
                if isCurrentUser {
                    Text(message.status.rawValue.capitalized)
                        .font(.caption2).foregroundColor(.secondary)
                }
            }
            if !isCurrentUser { Spacer() }
        }
        .id(message.id)
        .applyAppBackground()
    }
}

struct ChatScreen: View {
    @EnvironmentObject var authVM: AuthViewModel
    var partner: UserModel

    @State private var messages: [MessageModel] = []
    @State private var newMessage = ""
    @State private var selectedImage: PhotosPickerItem? = nil
    @State private var listener: ListenerRegistration?
    @State private var lastDocument: DocumentSnapshot?
    @State private var isLoadingMore = false

    private let chatService = ChatService()
    private let firestoreService = FirestoreService()
    private let pageSize = 20

    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if isLoadingMore { ProgressView().padding() }
                        ForEach(messages) { message in
                            ChatMessageRow(
                                message: message,
                                isCurrentUser: message.senderID == authVM.currentUser?.id
                            )
                        }
                    }
                    .padding()
                    .onAppear { scrollToBottom(proxy) }
                    .onChange(of: messages.count) { _ in scrollToBottom(proxy) }
                }
                .gesture(DragGesture().onChanged { value in
                    if value.translation.height > 50 { loadMoreMessages() }
                })
            }

            // Input bar
            HStack(spacing: 8) {
                PhotosPicker(selection: $selectedImage, matching: .images) {
                    Image(systemName: "photo").font(.title2)
                }
                TextField("Type a message...", text: $newMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(minHeight: 30)
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill").padding(.horizontal)
                }
            }
            .padding()
        }
        .navigationTitle(partner.name)
        .onAppear(perform: initialLoad)
        .onDisappear { listener?.remove() }
        .task(id: selectedImage) { await handleImageUpload() }
    }

    // MARK: - Loading & Streaming
    private func initialLoad() {
        guard let currentUserID = authVM.currentUser?.id,
              let partnerID = partner.id else { return }
        let threadID = generateThreadID(currentUserID, partnerID)
        Task {
            do {
                let (msgs, lastDoc) = try await chatService.loadMessages(threadID: threadID, limit: pageSize)
                self.messages = msgs
                self.lastDocument = lastDoc
                startStreamingMessages(threadID)
                try await chatService.markThreadAsRead(threadID: threadID, userID: currentUserID)
            } catch {
                print("Failed initial load: \(error.localizedDescription)")
            }
        }
    }

    private func loadMoreMessages() {
        guard !isLoadingMore,
              let lastDoc = lastDocument,
              let currentUserID = authVM.currentUser?.id,
              let partnerID = partner.id else { return }
        let threadID = generateThreadID(currentUserID, partnerID)
        isLoadingMore = true
        Task {
            do {
                let (msgs, newLast) = try await chatService.loadMessages(threadID: threadID, limit: pageSize, startAfter: lastDoc)
                self.messages.insert(contentsOf: msgs, at: 0)
                self.lastDocument = newLast
            } catch {
                print("Pagination failed: \(error.localizedDescription)")
            }
            isLoadingMore = false
        }
    }

    private func startStreamingMessages(_ threadID: String) {
        guard let currentUserID = authVM.currentUser?.id else { return }
        listener = chatService.streamMessages(for: threadID) { fetchedMessages in
            self.messages = fetchedMessages
            Task { await markMessagesAsRead(fetchedMessages, currentUserID: currentUserID) }
        }
    }

    private func markMessagesAsRead(_ fetchedMessages: [MessageModel], currentUserID: String) async {
        let unread = fetchedMessages.filter { $0.recipientID == currentUserID && $0.status != .read }
        for message in unread {
            if let id = message.id {
                try? await firestoreService.updateMessageStatus(id: id, status: .read)
            }
        }

        guard let partnerID = partner.id else { return }
        let threadID = generateThreadID(currentUserID, partnerID)
        let threadRef = Firestore.firestore().collection("chatThreads").document(threadID)
        do {
            try await threadRef.updateData(["unreadCounts.\(currentUserID)": 0])
        } catch {
            print("Failed to reset unread count: \(error.localizedDescription)")
        }
    }

    // MARK: - Sending
    private func sendMessage() {
        guard (!newMessage.trimmingCharacters(in: .whitespaces).isEmpty || selectedImage != nil),
              let senderID = authVM.currentUser?.id,
              let recipientID = partner.id else { return }
        let senderName = authVM.currentUser?.name ?? "Someone"

        let threadID = generateThreadID(senderID, recipientID)
        let message = MessageModel(
            id: nil, senderID: senderID, recipientID: recipientID,
            text: newMessage, timestamp: Date(),
            firstResponseAt: nil, chatThreadID: threadID,
            imageURL: nil, status: .sent
        )

        Task {
            do {
                try await firestoreService.sendMessage(message)
                newMessage = ""
                try await firestoreService.createOrUpdateChatThread(
                    threadID: threadID,
                    participants: [senderID, recipientID],
                    lastMessage: message.text.isEmpty ? "[Image]" : message.text,
                    lastSenderID: senderID
                )
                await handleResponseTracking(for: message)
                NotificationManager.shared.notifyNewMessage(to: recipientID, senderName: senderName)
            } catch {
                print("Send message failed: \(error.localizedDescription)")
            }
        }
    }

    private func handleImageUpload() async {
        guard let item = selectedImage,
              let data = try? await item.loadTransferable(type: Data.self),
              let senderID = authVM.currentUser?.id,
              let recipientID = partner.id else {
            selectedImage = nil
            return
        }
        let senderName = authVM.currentUser?.name ?? "Someone"

        let threadID = generateThreadID(senderID, recipientID)
        do {
            let fileName = UUID().uuidString + ".jpg"
            let url = try await firestoreService.uploadImage(data, fileName: fileName)
            let message = MessageModel(
                id: nil, senderID: senderID, recipientID: recipientID,
                text: "", timestamp: Date(),
                firstResponseAt: nil, chatThreadID: threadID,
                imageURL: url, status: .sent
            )
            try await firestoreService.sendMessage(message)
            try await firestoreService.createOrUpdateChatThread(
                threadID: threadID,
                participants: [senderID, recipientID],
                lastMessage: "[Image]",
                lastSenderID: senderID
            )
            await handleResponseTracking(for: message)
            NotificationManager.shared.notifyNewImage(to: recipientID, senderName: senderName)
        } catch {
            print("Image upload/send failed: \(error.localizedDescription)")
        }
        selectedImage = nil
    }

    // MARK: - Helpers
    private func generateThreadID(_ id1: String, _ id2: String) -> String {
        [id1, id2].sorted().joined(separator: "_")
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        if let last = messages.last?.id {
            DispatchQueue.main.async { proxy.scrollTo(last, anchor: .bottom) }
        }
    }

    private func handleResponseTracking(for message: MessageModel) async {
        guard let currentUserID = authVM.currentUser?.id,
              let businessID = authVM.currentUser?.businessID else { return }
        do {
            let db = Firestore.firestore()
            let incomingQuery = db.collection("messages")
                .whereField("chatThreadID", isEqualTo: message.chatThreadID)
                .whereField("recipientID", isEqualTo: currentUserID)
                .order(by: "timestamp", descending: false)
            let snapshot = try await incomingQuery.getDocuments()
            if let firstUnresponded = snapshot.documents.first(where: { $0.data()["firstResponseAt"] == nil }) {
                let msgID = firstUnresponded.documentID
                let originalTimestamp = (firstUnresponded.data()["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                try await db.collection("messages").document(msgID).updateData(["firstResponseAt": Date()])
                let responseTime = Date().timeIntervalSince(originalTimestamp)
                try await firestoreService.saveResponseTime(forBusinessID: businessID, responseTime: responseTime)
            }
        } catch {
            print("Response tracking failed: \(error.localizedDescription)")
        }
    }
}
