// ProfileSetupScreen.swift

import SwiftUI
import PhotosUI
import FirebaseFirestore

struct ProfileSetupScreen: View {
    let userRole: UserRole
    var joiningBusiness: Bool = false
    var onComplete: () -> Void
    var onBack: () -> Void

    @State private var bio = ""
    @State private var businessName = ""
    @State private var businessCode = ""
    @State private var phoneNumber = ""
    @State private var selectedImage: UIImage?
    @State private var selectedItem: PhotosPickerItem?
    @State private var businessBio = ""

    @State private var ecoFriendly = false
    @State private var petFriendly = false
    @State private var familyOwned = false

    @State private var errorMessage: String?

    @EnvironmentObject var authVM: AuthViewModel
    
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "photo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.gray)
                    }
                }
                .onChange(of: selectedItem) { newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            selectedImage = image
                        }
                    }
                }

                if userRole == .teen {
                    if joiningBusiness {
                        TextField("Business Code", text: $businessCode)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.allCharacters)
                            .onChange(of: businessCode) { newValue in
                                businessCode = newValue.uppercased()
                            }
                    } else {
                        TextField("Business Name", text: $businessName)
                            .textFieldStyle(.roundedBorder)

                        Toggle("Eco Friendly", isOn: $ecoFriendly)
                        Toggle("Pet Friendly", isOn: $petFriendly)
                        Toggle("Family Owned", isOn: $familyOwned)
                    }

                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .textFieldStyle(.roundedBorder)
                }

                TextField("Your Bio", text: $bio)
                    .textFieldStyle(.roundedBorder)
                
                if userRole == .teen && !joiningBusiness {
                    TextField("Business Bio", text: $businessBio)
                        .textFieldStyle(.roundedBorder)
                }

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }

                Button("Finish Setup") {
                    Task { await finishSetup() }
                }
                .padding()
                .background(Color.accentColor)
                .foregroundColor(Color("BGColor"))
                .clipShape(Capsule())
            }
            .padding()
        }
        .navigationTitle("Profile Setup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    onBack()
                }) {
                    Label("Back", systemImage: "chevron.left")
                }
            }
        }
        .applyAppBackground()
    }

    private func finishSetup() async {
        errorMessage = nil

        guard userRole == .teen else {
            await completeWithProfileImageOnly()
            return
        }

        // Validate phone number
        let trimmedPhone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let phoneRegex = "^\\d{10}$"
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        guard phonePredicate.evaluate(with: trimmedPhone) else {
            errorMessage = "Enter a valid 10-digit phone number."
            return
        }

        do {
            var imageURL: String? = nil
            if let image = selectedImage {
                imageURL = try await authVM.uploadProfileImage(image)
            }

            if joiningBusiness {
                try await joinExistingBusiness(with: businessCode)
            } else {
                try await authVM.setupBusinessProfile(
                    url: imageURL,
                    bio: bio,
                    businessName: businessName,
                    ecoFriendly: ecoFriendly,
                    petFriendly: petFriendly,
                    familyOwned: familyOwned
                )
            }

            if let userID = authVM.currentUser?.id {
                try await Firestore.firestore().collection("users").document(userID).updateData([
                    "phoneNumber": trimmedPhone
                ])
            }

            onComplete()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func completeWithProfileImageOnly() async {
        do {
            var imageURL: String? = nil
            if let image = selectedImage {
                imageURL = try await authVM.uploadProfileImage(image)
            }

            try await authVM.updateUserProfile(url: imageURL, bio: bio)
            onComplete()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func joinExistingBusiness(with code: String) async throws {
        let db = Firestore.firestore()
        
        // Look up business by supervisor code
        let snapshot = try await db.collection("businesses")
            .whereField("businessCode", isEqualTo: code.uppercased())
            .getDocuments()
        
        guard let businessDoc = snapshot.documents.first else {
            throw NSError(domain: "JoinError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid business code."])
        }

        let businessID = businessDoc.documentID
        guard let user = authVM.currentUser else { return }

        // Create membership request document
        let request = MembershipRequestModel(
            businessID: businessID,
            userID: user.id!,
            userName: user.name,
            status: "pending",
            timestamp: Date()
        )

        _ = try db.collection("membershipRequests").addDocument(from: request)

        // Update user to reflect pending request (but keep role as homeowner)
        try await db.collection("users").document(user.id!).updateData([
            "businessID": businessID,
            "role": UserRole.homeowner.rawValue,
            "pendingBusinessMembership": true
        ])

        try await authVM.refreshCurrentUser()
    }
}
