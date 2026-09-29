// ContactUsWindow.swift

import SwiftUI

struct ContactUsWindow: View {
    @Environment(\.dismiss) var dismiss

    @State private var subject: String = ""
    @State private var message: String = ""
    @State private var showAlert = false
    @State private var showSuccessMessage = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Subject")) {
                    TextField("Subject", text: $subject)
                }

                Section(header: Text("Message")) {
                    TextEditor(text: $message)
                        .frame(height: 150)
                }

                if showSuccessMessage {
                    Section {
                        Text("Your message has been sent. Thank you!")
                            .foregroundColor(.green)
                    }
                }
            }
            .navigationTitle("Contact Us")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        if subject.isEmpty || message.isEmpty {
                            showAlert = true
                        } else {
                            showSuccessMessage = true
                            // Optionally send to Firestore, analytics, etc.
                            print("📩 Contact Form Sent:")
                            print("Subject: \(subject)")
                            print("Message: \(message)")
                        }
                    }
                    .disabled(subject.isEmpty || message.isEmpty)
                }
            }
            .alert("Please complete all fields.", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            }
        }
    }
}
