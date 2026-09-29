// BusinessSetupScreen.swift

import SwiftUI
import FirebaseFirestore

struct BusinessSetupScreen: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isJoiningOrganization = false

    @State private var businessName = ""
    @State private var bio = ""
    @State private var businessCode = ""

    @State private var ecoFriendly = false
    @State private var petFriendly = false
    @State private var familyOwned = false

    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Picker("Action", selection: $isJoiningOrganization) {
                    Text("Create Business").tag(false)
                    Text("Join Business").tag(true)
                }
                .pickerStyle(.segmented)
            }

            if isJoiningOrganization {
                Section(header: Text("Join Organization")) {
                    TextField("Business Code", text: $businessCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }
            } else {
                Section(header: Text("Business Info")) {
                    TextField("Business Name", text: $businessName)
                    TextField("Bio", text: $bio)
                }

                Section(header: Text("Badges")) {
                    Toggle("Eco Friendly", isOn: $ecoFriendly)
                    Toggle("Pet Friendly", isOn: $petFriendly)
                    Toggle("Family Owned", isOn: $familyOwned)
                }
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
            }

            Button(isJoiningOrganization ? "Request to Join" : "Create Business") {
                Task {
                    isJoiningOrganization ? await handleJoinRequest() : await createBusiness()
                }
            }
            .disabled(isJoiningOrganization ? businessCode.isEmpty : businessName.isEmpty || isSubmitting)
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Business Setup")
        .applyAppBackground()
    }

    private func createBusiness() async {
        isSubmitting = true
        errorMessage = nil

        do {
            await authVM.updateUserRole(to: .teen)

            try await authVM.setupBusinessProfile(
                url: authVM.currentUser?.profileImageURL ?? "",
                bio: bio,
                businessName: businessName,
                ecoFriendly: ecoFriendly,
                petFriendly: petFriendly,
                familyOwned: familyOwned
            )

            dismiss()
        } catch {
            errorMessage = "Failed to create business: \(error.localizedDescription)"
        }

        isSubmitting = false
    }

    private func handleJoinRequest() async {
        isSubmitting = true
        errorMessage = nil

        let code = businessCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        do {
            let db = Firestore.firestore()
            let snapshot = try await db.collection("businesses")
                .whereField("businessCode", isEqualTo: code)
                .getDocuments()

            guard let businessDoc = snapshot.documents.first else {
                errorMessage = "Invalid business code."
                isSubmitting = false
                return
            }

            guard let user = authVM.currentUser else { return }
            let businessID = businessDoc.documentID

            let request = MembershipRequestModel(
                businessID: businessID,
                userID: user.id!,
                userName: user.name,
                status: "pending",
                timestamp: Date()
            )

            _ = try db.collection("membershipRequests").addDocument(from: request)

            try await db.collection("users").document(user.id!).updateData([
                "businessID": businessID,
                "role": UserRole.homeowner.rawValue,
                "pendingBusinessMembership": true
            ])

            try await authVM.refreshCurrentUser()
            dismiss()

        } catch {
            errorMessage = "Failed to join business: \(error.localizedDescription)"
        }

        isSubmitting = false
    }
}
