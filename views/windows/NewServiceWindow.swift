// NewServiceWindow.swift

import SwiftUI
import PhotosUI

struct NewServiceWindow: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authVM: AuthViewModel

    @State private var title = ""
    @State private var description = ""
    @State private var price = ""
    @State private var selectedImage: UIImage?
    @State private var selectedItem: PhotosPickerItem?
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    private let firestoreService = FirestoreService()

    private var isFormValid: Bool {
        !title.isEmpty && !description.isEmpty && !price.isEmpty && Double(price) != nil
    }

    private var currencySymbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.currencySymbol ?? "$"
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("New Service")) {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description)
                    HStack {
                        Text(currencySymbol)
                        TextField("Price", text: $price)
                            .keyboardType(.decimalPad)
                    }
                }

                Section(header: Text("Service Image")) {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 150)
                                .clipped()
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(height: 150)
                                VStack(spacing: 8) {
                                    Image(systemName: "photo")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 40, height: 40)
                                        .foregroundColor(.gray)
                                    Text("Optional: Add a photo")
                                        .font(.footnote)
                                        .foregroundColor(.gray)
                                }
                            }
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
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("New Service")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveService() }
                    }
                    .disabled(!isFormValid || isSubmitting)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func saveService() async {
        guard let businessID = authVM.currentUser?.businessID,
              let priceValue = Double(price) else {
            errorMessage = "Invalid input."
            return
        }

        isSubmitting = true
        var imageURL: String?

        if let image = selectedImage,
           let data = image.jpegData(compressionQuality: 0.8) {
            do {
                let fileName = UUID().uuidString + ".jpg"
                imageURL = try await firestoreService.uploadImage(data, fileName: fileName)
            } catch {
                errorMessage = "Failed to upload image: \(error.localizedDescription)"
                isSubmitting = false
                return
            }
        }

        let newService = ServiceModel(
            id: nil,
            title: title,
            description: description,
            price: priceValue,
            businessID: businessID,
            timestamp: Date(),
            bookingsCount: 0,
            imageURL: imageURL
        )

        do {
            try await firestoreService.createService(newService)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSubmitting = false
    }
}

