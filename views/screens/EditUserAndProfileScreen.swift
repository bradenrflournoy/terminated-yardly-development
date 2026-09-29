// EditUserAndProfileScreen

import SwiftUI
import PhotosUI

struct EditUserAndProfileScreen: View {
    @EnvironmentObject var authVM: AuthViewModel

    @State private var name: String = ""
    @State private var bio: String = ""
    @State private var email: String = ""
    @State private var phoneNumber: String = ""
    @State private var newPassword: String = ""
    @State private var currentPassword: String = ""
    @State private var profileImage: PhotosPickerItem? = nil
    @State private var isSaving = false
    @State private var message: String?
    @State private var selectedImage: UIImage?

    private let firestoreService = FirestoreService()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                formFieldsSection
                messageSection
                buttonsSection
            }
            .padding()
            .frame(maxWidth: 400)
            .onAppear {
                if let user = authVM.currentUser {
                    name = user.name
                    email = user.email
                    bio = user.bio ?? ""
                    phoneNumber = user.phoneNumber ?? ""
                }
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .applyAppBackground()
    }

    private var formFieldsSection: some View {
        Group {
            PhotosPicker(selection: $profileImage, matching: .images) {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                } else if let urlString = authVM.currentUser?.profileImageURL,
                          let url = URL(string: urlString) {
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
            .onChange(of: profileImage) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        selectedImage = uiImage
                    }
                }
            }

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
            
            TextField("Bio", text: $bio)
                .textFieldStyle(.roundedBorder)

            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .textFieldStyle(.roundedBorder)
            
            TextField("Phone Number", text: $phoneNumber)
                .keyboardType(.phonePad)
                .textFieldStyle(.roundedBorder)

            SecureField("New Password", text: $newPassword)
                .textFieldStyle(.roundedBorder)

            SecureField("Current Password (needed for updates)", text: $currentPassword)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var messageSection: some View {
        Group {
            if let message = message {
                Text(message)
                    .foregroundColor(message.contains("successfully") ? .green : .red)
            }
        }
    }

    private var buttonsSection: some View {
        VStack(spacing: 10) {
            Button(action: saveProfile) {
                if isSaving {
                    ProgressView()
                } else {
                    Text("Save Changes")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(Color("BGColor"))
                        .cornerRadius(10)
                }
            }
            .disabled(name.isEmpty || email.isEmpty || phoneNumber.isEmpty || currentPassword.isEmpty)
        }
    }

    private func saveProfile() {
        guard var user = authVM.currentUser else { return }
        isSaving = true

        Task {
            do {
                // First, reauthenticate (always required)
                try await authVM.reauthenticate(currentPassword: currentPassword)

                // Now continue with changes only if reauthentication succeeded
                if let image = selectedImage,
                   let data = image.jpegData(compressionQuality: 0.8) {
                    let fileName = "profile_\(user.id ?? UUID().uuidString).jpg"
                    if let url = try? await firestoreService.uploadImage(data, fileName: fileName) {
                        user.profileImageURL = url
                    }
                }

                user.name = name
                user.bio = bio
                user.phoneNumber = phoneNumber

                try await firestoreService.updateUserProfile(user)

                if let userID = user.id {
                    let updatedUser = try await firestoreService.fetchUser(byID: userID)
                    authVM.currentUser = updatedUser
                }

                if email != authVM.currentUser?.email {
                    try await authVM.updateEmail(email)
                }

                if !newPassword.isEmpty {
                    try await authVM.updatePassword(newPassword)
                }

                message = "Profile updated successfully."

            } catch {
                message = "Failed to update profile: \(error.localizedDescription)"
            }

            isSaving = false
        }
    }
}
