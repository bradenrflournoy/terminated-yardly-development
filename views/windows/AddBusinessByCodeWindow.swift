// AddBusinessByCodeWindow.swift

import SwiftUI
import FirebaseFirestore
#if canImport(FirebaseFirestoreSwift)
import FirebaseFirestoreSwift   // works on your friend’s older toolchain
#endif

struct AddBusinessByCodeWindow: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authVM: AuthViewModel

    @State private var businessCode: String = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Enter Business Code")
                    .font(.headline)
                
                TextField("Business Code", text: $businessCode)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.allCharacters)
                    .onChange(of: businessCode) { newValue in
                        businessCode = newValue.uppercased()
                    }
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Button(action: { Task { await addBusinessByCode() } }) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Add Business")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color("AccentColor"))
                            .foregroundColor(Color("BGColor"))
                            .cornerRadius(10)
                    }
                }
                .opacity(businessCode.isEmpty ? 0.8 : 1.0) // manually dim
                .disabled(businessCode.isEmpty)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Add Business")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func addBusinessByCode() async {
        isLoading = true
        errorMessage = nil

        let db = Firestore.firestore()

        do {
            let snapshot = try await db.collection("businesses")
                .whereField("businessCode", isEqualTo: businessCode)
                .getDocuments()

            guard let document = snapshot.documents.first else {
                errorMessage = "No business found with that code."
                isLoading = false
                return
            }

            let businessID = document.documentID

            guard let supervisorID = authVM.currentUser?.id else {
                errorMessage = "Unexpected error. Try again."
                isLoading = false
                return
            }

            let userDoc = try await db.collection("users").document(supervisorID).getDocument()
            let userData = userDoc.data()
            let currentRequests = userData?["supervisedBusinessIDs"] as? [String] ?? []

            if currentRequests.contains(businessID) {
                errorMessage = "You already supervise this business."
                isLoading = false
                return
            }

            let supervisorName = userData?["name"] as? String ?? "Unknown"

            let request = SupervisionRequestModel(
                businessID: businessID,
                supervisorID: supervisorID,
                supervisorName: supervisorName,
                status: "pending",
                timestamp: Date()
            )

            _ = try db.collection("supervisionRequests").addDocument(from: request)
            dismiss()

        } catch {
            errorMessage = "Failed to send request: \(error.localizedDescription)"
        }

        isLoading = false
    }
}
