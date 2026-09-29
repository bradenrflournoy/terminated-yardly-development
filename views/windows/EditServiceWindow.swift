// EditServiceWindow.swift

import SwiftUI
import PhotosUI

struct EditServiceWindow: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authVM: AuthViewModel

    @State var service: ServiceModel
    @State private var errorMessage: String?
    @State private var isSaving = false

    @State private var selectedImage: UIImage?
    @State private var selectedItem: PhotosPickerItem?

    private let firestoreService = FirestoreService()
    
    private var currencySymbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.currencySymbol ?? "$"
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Edit Service")) {
                    TextField("Title", text: $service.title)
                    TextField("Description", text: $service.description)
                    HStack {
                        Text(currencySymbol)
                        TextField("Price", value: $service.price, format: .number)
                            .keyboardType(.decimalPad)
                    }
                }

                Section(header: Text("Service Image")) {
                    PhotosPicker(
                        selection: $selectedItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 150)
                                .clipped()
                        } else if let imageURL = service.imageURL, let url = URL(string: imageURL) {
                            AsyncImage(url: url) { image in
                                image.resizable()
                                    .scaledToFill()
                                    .frame(height: 150)
                                    .clipped()
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 150)
                            }
                        } else {
                            Text("Select an image")
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
                    Text(error)
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("Edit Service")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await updateService() }
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func updateService() async {
        guard let id = service.id else {
            errorMessage = "Invalid service ID."
            return
        }

        isSaving = true

        do {
            if let image = selectedImage,
               let data = image.jpegData(compressionQuality: 0.8) {
                let fileName = UUID().uuidString + ".jpg"
                let url = try await firestoreService.uploadImage(data, fileName: fileName)
                service.imageURL = url
            }

            try await firestoreService.updateService(service, id: id)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}
