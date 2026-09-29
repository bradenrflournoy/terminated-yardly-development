// BusinessSettingsScreen.swift

import SwiftUI
import PhotosUI
import FirebaseFirestore

struct BusinessSettingsScreen: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var businessName: String = ""
    @State private var bio: String = ""
    @State private var selectedImage: PhotosPickerItem? = nil
    @State private var profileImageURL: URL? = nil
    @State private var isSaving = false
    @State private var businessCode: String = ""
    @State private var isManager = false
    @State private var businessType: BusinessType = .individual
    @State private var members: [UserModel] = []
    @State private var showTransferConfirmation = false
    @State private var showTransferSuccess = false
    @State private var isTransferringManager = false
    @State private var isOpeningAvailability = false
    @State private var selectedActionUser: UserModel? = nil
    @State private var showRemoveConfirmation = false
    @State private var showLeaveConfirmation = false

    private let firestoreService = FirestoreService()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PhotosPicker(selection: $selectedImage, matching: .images) {
                    if let url = profileImageURL {
                        AsyncImage(url: url) { image in
                            image.resizable()
                                 .scaledToFill()
                                 .frame(width: 120, height: 120)
                                 .clipShape(Circle())
                        } placeholder: {
                            ProgressView()
                        }
                    } else {
                        Image(systemName: "photo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.gray)
                    }
                }
                .disabled(!isManager)

                TextField("Business Name", text: $businessName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .disabled(!isManager)

                TextField("Business Bio", text: $bio, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(4, reservesSpace: true)
                    .padding(.horizontal)
                    .disabled(!isManager)

                if isManager {
                    Button(action: {
                        isOpeningAvailability = true
                    }) {
                        Label("Edit Availability", systemImage: "calendar.badge.clock")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .background(Color.accentColor)
                    .foregroundColor(Color("BGColor"))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .disabled(isSaving || isOpeningAvailability)
                    
                    Button {
                        isSaving = true
                        Task {
                            await saveChanges()
                            isSaving = false
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Text("Save Changes")
                                .bold()
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                    .background(Color.accentColor)
                    .foregroundColor(Color("BGColor"))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .disabled(isSaving)
                }
                    
                if businessType == .organization && isManager {
                    VStack(spacing: 16) {
                        Text("Manage Members")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)

                        Picker("Select Member", selection: $selectedActionUser) {
                            Text("Select").tag(Optional<UserModel>.none)
                            ForEach(members) { member in
                                Text(member.name).tag(Optional(member))
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .padding(.horizontal)

                        Button("Transfer Manager") {
                            showTransferConfirmation = true
                        }
                        .disabled(selectedActionUser == nil)
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)

                        Button("Remove Member") {
                            showRemoveConfirmation = true
                        }
                        .disabled(selectedActionUser == nil)
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    }
                    .padding()
                    .task {
                        await loadMembers()
                    }
                    .confirmationDialog("Are you sure you want to remove this member?", isPresented: $showRemoveConfirmation) {
                        Button("Remove", role: .destructive) {
                            if let member = selectedActionUser {
                                Task {
                                    await removeMember(memberID: member.id ?? "")
                                    selectedActionUser = nil
                                    await loadMembers()
                                }
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    }
                    .confirmationDialog("Transfer manager role to \(selectedActionUser?.name ?? "this user")?", isPresented: $showTransferConfirmation) {
                        Button("Transfer", role: .destructive) {
                            if let member = selectedActionUser {
                                Task {
                                    await transferManager(to: member)
                                    selectedActionUser = nil
                                    showTransferSuccess = true
                                }
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    }
                    .alert("Success", isPresented: $showTransferSuccess) {
                        Button("OK", role: .cancel) {}
                    } message: {
                        Text("The manager role has been successfully transferred.")
                    }
                } else if businessType == .organization {
                    Button("Leave Business") {
                        showLeaveConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    .background(Color(.systemGray6))
                    .foregroundColor(.red)
                    .padding(.horizontal)
                    .confirmationDialog("Are you sure you want to leave this business?", isPresented: $showLeaveConfirmation) {
                        Button("Leave", role: .destructive) {
                            Task {
                                await leaveBusiness()
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    }
                }

                if !businessCode.isEmpty {
                    VStack(spacing: 4) {
                        Text("Business Code")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(businessCode)
                            .font(.headline)
                            .monospacedDigit()
                            .padding(6)
                            .background(Color(.systemGray5))
                            .cornerRadius(6)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .applyAppBackground()
        .sheet(isPresented: $isOpeningAvailability) {
            EditAvailabilityWindow()
                .environmentObject(authVM)
        }
        .task {
            await loadBusinessDetails()
        }
        .task(id: selectedImage) {
            await handleImageUpload()
        }
    }

    private func loadBusinessDetails() async {
        guard let businessID = authVM.currentUser?.businessID else { return }

        do {
            let doc = try await Firestore.firestore().collection("businesses").document(businessID).getDocument()
            if let data = doc.data() {
                businessName = data["businessName"] as? String ?? ""
                bio = data["bio"] as? String ?? ""
                if let urlString = data["profileImageURL"] as? String,
                   let url = URL(string: urlString) {
                    profileImageURL = url
                }
                if let code = data["businessCode"] as? String {
                    businessCode = code
                }
                if let manager = data["managerID"] as? String {
                    isManager = (manager == authVM.currentUser?.id)
                }
                if let typeRaw = data["businessType"] as? String,
                   let type = BusinessType(rawValue: typeRaw) {
                    businessType = type
                }
            }
        } catch {
            print("Failed to load business details: \(error.localizedDescription)")
        }
    }

    private func saveChanges() async {
        guard let businessID = authVM.currentUser?.businessID else { return }

        var data: [String: Any] = [
            "businessName": businessName,
            "bio": bio
        ]

        if let newURL = profileImageURL?.absoluteString {
            data["profileImageURL"] = newURL
        }

        do {
            try await Firestore.firestore().collection("businesses").document(businessID).updateData(data)
        } catch {
            print("Failed to update business info: \(error.localizedDescription)")
        }
    }

    private func handleImageUpload() async {
        guard let item = selectedImage,
              let data = try? await item.loadTransferable(type: Data.self) else {
            selectedImage = nil
            return
        }

        do {
            let fileName = UUID().uuidString + ".jpg"
            let url = try await firestoreService.uploadImage(data, fileName: fileName)
            profileImageURL = URL(string: url)
        } catch {
            print("Image upload failed: \(error.localizedDescription)")
        }

        selectedImage = nil
    }
    
    private func loadMembers() async {
        guard let businessID = authVM.currentUser?.businessID,
              let currentUserID = authVM.currentUser?.id else { return }

        do {
            let snapshot = try await Firestore.firestore().collection("users")
                .whereField("businessID", isEqualTo: businessID)
                .getDocuments()

            let users = try snapshot.documents.compactMap {
                try $0.data(as: UserModel.self)
            }

            members = users.filter { $0.id != currentUserID }
        } catch {
            print("Failed to load members: \(error.localizedDescription)")
        }
    }
    
    private func transferManager(to newManager: UserModel) async {
        guard let businessID = authVM.currentUser?.businessID else { return }

        do {
            try await Firestore.firestore().collection("businesses").document(businessID)
                .updateData(["managerID": newManager.id ?? ""])

            print("Manager role transferred to \(newManager.name)")
        } catch {
            print("Failed to transfer manager: \(error.localizedDescription)")
        }
    }
    
    private func removeMember(memberID: String) async {
        guard let businessID = authVM.currentUser?.businessID else { return }

        do {
            try await Firestore.firestore().collection("businesses").document(businessID).updateData([
                "memberIDs": FieldValue.arrayRemove([memberID])
            ])

            // Re-check member count after removal
            let businessRef = Firestore.firestore().collection("businesses").document(businessID)
            let snapshot = try await businessRef.getDocument()
            let remainingMembers = snapshot.data()?["memberIDs"] as? [String] ?? []

            try await businessRef.updateData([
                "businessType": (remainingMembers.count > 1 ? BusinessType.organization.rawValue : BusinessType.individual.rawValue)
            ])

            try await Firestore.firestore().collection("users").document(memberID).updateData([
                "businessID": FieldValue.delete(),
                "role": UserRole.homeowner.rawValue
            ])

            try await authVM.refreshCurrentUser()
        } catch {
            print("Failed to remove member: \(error)")
        }
    }
    
    @MainActor
    private func leaveBusiness() async {
        guard let user = authVM.currentUser,
              let businessID = user.businessID else { return }

        do {
            let db = Firestore.firestore()

            // Remove from business memberIDs
            try await db.collection("businesses").document(businessID).updateData([
                "memberIDs": FieldValue.arrayRemove([user.id!])
            ])

            // Re-check member count
            let businessRef = db.collection("businesses").document(businessID)
            let snapshot = try await businessRef.getDocument()
            let remainingMembers = snapshot.data()?["memberIDs"] as? [String] ?? []

            try await businessRef.updateData([
                "businessType": (remainingMembers.count > 1 ? BusinessType.organization.rawValue : BusinessType.individual.rawValue)
            ])

            // Update user profile
            try await db.collection("users").document(user.id!).updateData([
                "businessID": FieldValue.delete(),
                "role": UserRole.homeowner.rawValue
            ])

            try await authVM.refreshCurrentUser()
        } catch {
            print("Error leaving business: \(error.localizedDescription)")
        }
    }
}
